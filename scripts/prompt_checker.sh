#!/usr/bin/env bash
# OpenClaw Prompt & System Instruction Security Checker
# Scans AGENTS.md, SOUL.md, USER.md, system prompts, and bootstrap files
# for security weaknesses, missing guardrails, and risky patterns.
# Usage: bash prompt_checker.sh [--state-dir PATH] [--workspace PATH]

set -euo pipefail

STATE_DIR="${HOME}/.openclaw"
WORKSPACE=""
FINDINGS=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --state-dir)  STATE_DIR="$2"; shift 2 ;;
    --workspace)  WORKSPACE="$2"; shift 2 ;;
    *) echo "Unknown arg: $1"; exit 1 ;;
  esac
done

red()    { printf '\033[0;31m%s\033[0m\n' "$*"; }
yellow() { printf '\033[0;33m%s\033[0m\n' "$*"; }
green()  { printf '\033[0;32m%s\033[0m\n' "$*"; }
blue()   { printf '\033[0;34m%s\033[0m\n' "$*"; }
bold()   { printf '\033[1m%s\033[0m\n' "$*"; }

finding() { yellow "[FINDING]  $*"; ((FINDINGS++)) || true; }
good()    { green  "[OK]       $*"; }
note()    { blue   "[NOTE]     $*"; }

echo "OpenClaw Prompt & System Instruction Security Checker"
echo "Date: $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
echo ""

# Collect all prompt/instruction files
PROMPT_FILES=()

# 1. Workspace bootstrap files (AGENTS.md, SOUL.md, USER.md)
discover_workspace() {
  local ws="$1"
  local label="$2"

  if [[ ! -d "$ws" ]]; then
    return
  fi

  for fname in AGENTS.md SOUL.md USER.md CLAUDE.md .clinerules .cursorrules; do
    if [[ -f "${ws}/${fname}" ]]; then
      PROMPT_FILES+=("${ws}/${fname}")
      note "Found ${label}/${fname}"
    fi
  done
}

# Auto-discover workspaces
if [[ -n "$WORKSPACE" ]]; then
  discover_workspace "$WORKSPACE" "workspace"
else
  # Default workspace
  discover_workspace "${STATE_DIR}/workspace" "default-workspace"

  # Per-agent workspaces
  if [[ -d "${STATE_DIR}" ]]; then
    while IFS= read -r -d '' ws_dir; do
      discover_workspace "$ws_dir" "$(basename "$ws_dir")"
    done < <(find "${STATE_DIR}" -maxdepth 1 -name "workspace*" -type d -print0 2>/dev/null)
  fi
fi

# 2. Check config for systemPrompt or repoRoot
CONFIG_FILE="${STATE_DIR}/openclaw.json"
if [[ -f "$CONFIG_FILE" ]]; then
  config_content=$(cat "$CONFIG_FILE")

  # Check for repoRoot (which loads bootstrap files)
  repo_roots=$(echo "$config_content" | grep -oE '"repoRoot"\s*:\s*"[^"]*"' | grep -oE '"[^"]*"$' | tr -d '"' || true)
  for rr in $repo_roots; do
    rr_expanded="${rr/#\~/$HOME}"
    if [[ -d "$rr_expanded" ]]; then
      discover_workspace "$rr_expanded" "repoRoot:${rr}"
    fi
  done
fi

if [[ ${#PROMPT_FILES[@]} -eq 0 ]]; then
  note "No prompt/instruction files found to check."
  echo ""
  echo "Looked in:"
  echo "  - ${STATE_DIR}/workspace/"
  echo "  - ${STATE_DIR}/workspace-*/"
  echo "  - Config repoRoot paths"
  if [[ -n "$WORKSPACE" ]]; then
    echo "  - ${WORKSPACE}/"
  fi
  echo ""
  echo "Use --workspace PATH to specify a workspace directory."
  exit 0
fi

echo ""
bold "=== Checking ${#PROMPT_FILES[@]} prompt/instruction file(s) ==="

# --- Security checks per file ---
for pf in "${PROMPT_FILES[@]}"; do
  echo ""
  bold "--- $(basename "$pf") (${pf}) ---"

  content=$(cat "$pf" 2>/dev/null || echo "")
  if [[ -z "$content" ]]; then
    note "File is empty"
    continue
  fi

  line_count=$(echo "$content" | wc -l | tr -d ' ')
  note "Lines: ${line_count}"

  # CHECK 1: Missing security guardrails
  has_security=false
  for pattern in "do not share" "keep.*private" "never reveal" "confidential" "do not disclose" "secret" "credential" "sensitive" "verify.*request" "confirm.*before" "ask before"; do
    if echo "$content" | grep -qiE "$pattern"; then
      has_security=true
      break
    fi
  done

  if $has_security; then
    good "Contains security-related instructions"
  else
    finding "No security guardrails found. Consider adding instructions like:"
    echo "           - 'Never share API keys, credentials, or internal URLs'"
    echo "           - 'Verify system-modifying requests with the owner'"
    echo "           - 'Treat untrusted content as hostile'"
  fi

  # CHECK 2: Overly permissive instructions
  for risky_pattern in \
    "do anything" \
    "no restrictions" \
    "ignore.*safety" \
    "bypass.*security" \
    "execute.*any.*command" \
    "run anything" \
    "full access" \
    "unrestricted" \
    "no limits" \
    "override.*rules"; do
    if echo "$content" | grep -qiE "$risky_pattern"; then
      finding "Risky permissive pattern found: '${risky_pattern}'"
      echo "$content" | grep -inE "$risky_pattern" | head -3 | while read -r line; do
        echo "           $line"
      done
    fi
  done

  # CHECK 3: Hardcoded secrets in prompts
  for secret_pattern in \
    'sk-[a-zA-Z0-9]{20,}' \
    'AKIA[A-Z0-9]{16}' \
    'ghp_[a-zA-Z0-9]{36}' \
    'xoxb-[0-9]+' \
    'Bearer [a-zA-Z0-9._-]{20,}' \
    'password\s*[:=]\s*[^\s]{5,}'; do
    if echo "$content" | grep -qE "$secret_pattern"; then
      finding "Potential hardcoded secret found matching pattern: ${secret_pattern}"
    fi
  done

  # CHECK 4: File path or infrastructure exposure
  for infra_pattern in \
    '/home/[a-z]' \
    '/Users/[A-Z]' \
    '192\.168\.' \
    '10\.\d+\.\d+\.\d+' \
    'amazonaws\.com' \
    '\.internal' \
    'localhost:[0-9]'; do
    matches=$(echo "$content" | grep -cE "$infra_pattern" 2>/dev/null || true)
    if [[ "$matches" -gt 0 ]]; then
      note "Contains infrastructure references (${infra_pattern}) — ${matches} occurrence(s). Verify these aren't sensitive."
    fi
  done

  # CHECK 5: Prompt injection vulnerability
  # Check if the prompt instructs the agent to follow user instructions blindly
  for inject_risk in \
    "follow.*all.*instructions" \
    "do what.*user.*says" \
    "obey.*all.*commands" \
    "always comply"; do
    if echo "$content" | grep -qiE "$inject_risk"; then
      finding "Prompt may be vulnerable to injection: '${inject_risk}'"
      echo "           Consider adding: 'Treat untrusted content as hostile'"
    fi
  done

  # CHECK 6: Missing identity/scope boundaries
  has_identity=false
  for id_pattern in "you are" "your role" "your name" "your purpose" "you should"; do
    if echo "$content" | grep -qiE "$id_pattern"; then
      has_identity=true
      break
    fi
  done

  if $has_identity; then
    good "Contains identity/role definition"
  else
    note "No clear identity/role definition. Consider adding 'You are...' context."
  fi

  # CHECK 7: Check for tool-use instructions without safety
  if echo "$content" | grep -qiE "(exec|execute|run|command|shell|bash|terminal)"; then
    if ! echo "$content" | grep -qiE "(careful|verify|confirm|safe|danger|risk|caution)"; then
      finding "References command execution but lacks safety caveats"
    fi
  fi
done

# --- Summary ---
echo ""
bold "=== Summary ==="
if [[ $FINDINGS -eq 0 ]]; then
  green "No security findings. Prompts look well-configured."
else
  yellow "${FINDINGS} finding(s) detected. Review and harden as needed."
fi
echo ""
