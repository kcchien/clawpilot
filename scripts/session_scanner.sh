#!/usr/bin/env bash
# OpenClaw Session Transcript Scanner
# Scans session .jsonl files for leaked secrets, sensitive data, and anomalies.
# Usage: bash session_scanner.sh [--state-dir PATH] [--agent AGENT_ID] [--max-files N] [--deep]

set -euo pipefail

STATE_DIR="${HOME}/.openclaw"
AGENT_ID=""
MAX_FILES=20
DEEP=false
FINDINGS=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --state-dir)  STATE_DIR="$2"; shift 2 ;;
    --agent)      AGENT_ID="$2"; shift 2 ;;
    --max-files)  MAX_FILES="$2"; shift 2 ;;
    --deep)       DEEP=true; shift ;;
    *) echo "Unknown arg: $1"; exit 1 ;;
  esac
done

red()    { printf '\033[0;31m%s\033[0m\n' "$*"; }
yellow() { printf '\033[0;33m%s\033[0m\n' "$*"; }
green()  { printf '\033[0;32m%s\033[0m\n' "$*"; }
blue()   { printf '\033[0;34m%s\033[0m\n' "$*"; }
bold()   { printf '\033[1m%s\033[0m\n' "$*"; }

finding()  { yellow "[FINDING]  $*"; ((FINDINGS++)) || true; }
critical() { red    "[CRITICAL] $*"; ((FINDINGS++)) || true; }
good()     { green  "[OK]       $*"; }
note()     { blue   "[NOTE]     $*"; }

echo "OpenClaw Session Transcript Scanner"
echo "Date: $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
echo ""

# Determine session directories to scan
SEARCH_DIR="${STATE_DIR}/agents"
if [[ -n "$AGENT_ID" ]]; then
  SEARCH_DIR="${STATE_DIR}/agents/${AGENT_ID}/sessions"
  if [[ ! -d "$SEARCH_DIR" ]]; then
    red "Agent session directory not found: ${SEARCH_DIR}"
    exit 1
  fi
fi

if [[ ! -d "$SEARCH_DIR" ]]; then
  note "No agents directory found at ${SEARCH_DIR}"
  exit 0
fi

# Collect session files (most recent first, portable across macOS and Linux)
SESSION_FILES=()
while IFS= read -r f; do
  SESSION_FILES+=("$f")
done < <(find "$SEARCH_DIR" -name "*.jsonl" -type f -print0 2>/dev/null | xargs -0 ls -1t 2>/dev/null | head -n "$MAX_FILES")

# Fallback if xargs/ls approach returned nothing
if [[ ${#SESSION_FILES[@]} -eq 0 ]]; then
  while IFS= read -r -d '' f; do
    SESSION_FILES+=("$f")
    if [[ ${#SESSION_FILES[@]} -ge $MAX_FILES ]]; then
      break
    fi
  done < <(find "$SEARCH_DIR" -name "*.jsonl" -type f -print0 2>/dev/null)
fi

TOTAL_FILES=${#SESSION_FILES[@]}
echo "Found ${TOTAL_FILES} session file(s) to scan (max: ${MAX_FILES})"
echo ""

if [[ $TOTAL_FILES -eq 0 ]]; then
  note "No session files found"
  exit 0
fi

# --- Secret Patterns ---
# These are well-known credential patterns
SECRET_LABELS=(
  "AWS Access Key"
  "AWS Secret Key"
  "GitHub PAT"
  "GitHub OAuth"
  "Anthropic API Key"
  "OpenAI API Key"
  "Slack Bot Token"
  "Slack App Token"
  "Discord Bot Token"
  "Private Key"
  "Generic Bearer"
  "Telegram Bot Token"
  "Google API Key"
)
SECRET_REGEXES=(
  'AKIA[A-Z0-9]{16}'
  '(aws_secret_access_key|AWS_SECRET_ACCESS_KEY|SecretAccessKey)["\s:=]+[A-Za-z0-9/+=]{40}'
  'ghp_[a-zA-Z0-9]{36}'
  'gho_[a-zA-Z0-9]{36}'
  'sk-ant-[a-zA-Z0-9_-]{20,}'
  'sk-[a-zA-Z0-9]{20,}'
  'xoxb-[0-9]+-[a-zA-Z0-9]+'
  'xapp-[0-9]+-[a-zA-Z0-9]+'
  '[MN][A-Za-z0-9]{23,}\.[a-zA-Z0-9_-]{6}\.[a-zA-Z0-9_-]{27,}'
  '-----BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY-----'
  'Bearer [a-zA-Z0-9._-]{20,}'
  '[0-9]{8,}:[A-Za-z0-9_-]{35}'
  'AIza[A-Za-z0-9_-]{35}'
)

# --- Scan each file ---
files_with_secrets=0
total_secret_hits=0

for sf in "${SESSION_FILES[@]}"; do
  rel_path="${sf#${STATE_DIR}/}"
  file_hits=0
  file_size=$(du -h "$sf" 2>/dev/null | cut -f1)

  for i in "${!SECRET_LABELS[@]}"; do
    label="${SECRET_LABELS[$i]}"
    pattern="${SECRET_REGEXES[$i]}"
    hit_count=$(grep -cE "$pattern" "$sf" 2>/dev/null || true)
    if [[ "$hit_count" -gt 0 ]]; then
      if [[ $file_hits -eq 0 ]]; then
        echo ""
        bold "--- ${rel_path} (${file_size}) ---"
      fi
      critical "  ${label}: ${hit_count} match(es)"
      ((file_hits += hit_count)) || true
    fi
  done

  if [[ $file_hits -gt 0 ]]; then
    ((files_with_secrets++)) || true
    ((total_secret_hits += file_hits)) || true
  fi

  # Deep mode: additional checks
  if $DEEP; then
    # Check for IP addresses
    ip_count=$(grep -cE '\b([0-9]{1,3}\.){3}[0-9]{1,3}\b' "$sf" 2>/dev/null || true)
    if [[ "$ip_count" -gt 10 ]]; then
      if [[ $file_hits -eq 0 ]]; then
        echo ""
        bold "--- ${rel_path} (${file_size}) ---"
      fi
      note "  ${ip_count} IP address references found"
    fi

    # Check for base64-encoded blobs (potential encoded secrets)
    b64_count=$(grep -cE '[A-Za-z0-9+/]{40,}={0,2}' "$sf" 2>/dev/null || true)
    if [[ "$b64_count" -gt 5 ]]; then
      note "  ${b64_count} base64-like strings found (may contain encoded secrets)"
    fi

    # Check for file paths that reveal infrastructure
    path_count=$(grep -cE '(/home/[a-z]|/Users/[A-Z]|/etc/|/var/|C:\\Users\\)' "$sf" 2>/dev/null || true)
    if [[ "$path_count" -gt 0 ]]; then
      note "  ${path_count} file path references (infrastructure exposure)"
    fi

    # Check file age
    if [[ "$(uname)" == "Darwin" ]]; then
      file_age_days=$(( ( $(date +%s) - $(stat -f %m "$sf") ) / 86400 ))
    else
      file_age_days=$(( ( $(date +%s) - $(stat -c %Y "$sf") ) / 86400 ))
    fi
    if [[ $file_age_days -gt 90 ]]; then
      note "  File is ${file_age_days} days old — consider pruning"
    fi
  fi
done

# --- Size Analysis ---
echo ""
bold "=== Storage Analysis ==="

total_size=$(du -sh "${STATE_DIR}/agents" 2>/dev/null | cut -f1)
echo "  Total agent data: ${total_size}"

# Per-agent breakdown
for agent_dir in "${STATE_DIR}/agents"/*/; do
  if [[ -d "$agent_dir" ]]; then
    agent_name=$(basename "$agent_dir")
    agent_size=$(du -sh "$agent_dir" 2>/dev/null | cut -f1)
    session_count=$(find "$agent_dir" -name "*.jsonl" 2>/dev/null | wc -l | tr -d ' ')
    echo "  Agent '${agent_name}': ${agent_size} (${session_count} sessions)"
  fi
done

# --- Summary ---
echo ""
bold "=== Summary ==="
if [[ $files_with_secrets -gt 0 ]]; then
  red "  ${files_with_secrets} file(s) contain potential secrets (${total_secret_hits} total matches)"
  echo ""
  yellow "  Recommendations:"
  echo "    1. Review flagged transcripts and delete if they contain real secrets"
  echo "    2. Rotate any exposed credentials immediately"
  echo "    3. Enable log redaction: logging.redactSensitive: \"tools\""
  echo "    4. Consider session pruning: session.reset.mode: \"daily\""
  echo "    5. Avoid pasting secrets into chat messages"
else
  green "  No secrets detected in scanned transcripts"
fi
echo ""
echo "  Scanned: ${TOTAL_FILES} files"
echo "  Findings: ${FINDINGS}"
echo ""
