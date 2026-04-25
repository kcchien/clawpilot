#!/usr/bin/env bash
# OpenClaw Local Security Audit Script
# Performs deep security checks on a local OpenClaw installation.
# Usage: bash security_audit.sh [--state-dir PATH]
#
# Checks:
#   1. Version & CVE vulnerability
#   2. File/directory permissions
#   3. Credential exposure (tokens/keys in config)
#   4. Network binding & auth configuration
#   5. Sandbox & tool policy settings
#   6. DM policy & group access openness
#   7. Log redaction settings
#   8. Plugin/extension review
#   9. Skill supply chain security
#  10. Control UI security
#  11. Reverse proxy configuration
#  12. Gateway process exposure
#  13. Sensitive files in synced/shared folders
#  14. Session transcript secret scan
#
# Maps to OWASP Agentic Top 10 (ASI01-ASI10) and NIST CSF functions.

set -euo pipefail

STATE_DIR="${HOME}/.openclaw"
SEVERITY_COUNTS=()
CRITICAL=0
WARNING=0
INFO=0
PASS=0

# Parse args
while [[ $# -gt 0 ]]; do
  case "$1" in
    --state-dir) STATE_DIR="$2"; shift 2 ;;
    *) echo "Unknown arg: $1"; exit 1 ;;
  esac
done

CONFIG_FILE="${STATE_DIR}/openclaw.json"

# --- Helpers ---
red()    { printf '\033[0;31m%s\033[0m\n' "$*"; }
yellow() { printf '\033[0;33m%s\033[0m\n' "$*"; }
green()  { printf '\033[0;32m%s\033[0m\n' "$*"; }
blue()   { printf '\033[0;34m%s\033[0m\n' "$*"; }

critical() { red    "[CRITICAL] $*"; ((CRITICAL++)) || true; }
warning()  { yellow "[WARNING]  $*"; ((WARNING++))  || true; }
info()     { blue   "[INFO]     $*"; ((INFO++))     || true; }
pass()     { green  "[PASS]     $*"; ((PASS++))     || true; }

header() {
  echo ""
  echo "============================================"
  echo "  $*"
  echo "============================================"
}

# --- Pre-checks ---
header "OpenClaw Security Audit"
echo "State directory: ${STATE_DIR}"
echo "Config file:     ${CONFIG_FILE}"
echo "Date:            $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
echo "Framework:       OWASP Agentic Top 10 + NIST CSF"
echo ""

if [[ ! -d "${STATE_DIR}" ]]; then
  critical "State directory ${STATE_DIR} does not exist. Is OpenClaw installed?"
  echo ""
  echo "Summary: ${CRITICAL} critical, ${WARNING} warnings, ${INFO} info, ${PASS} passed"
  exit 1
fi

if [[ ! -f "${CONFIG_FILE}" ]]; then
  critical "Config file ${CONFIG_FILE} not found."
fi

# Read config once
config_content=""
if [[ -f "${CONFIG_FILE}" ]]; then
  config_content=$(cat "${CONFIG_FILE}" 2>/dev/null || echo "")
fi

# --- 1. Version & CVE Check [NIST: Identify] ---
header "1. Version & Known Vulnerabilities"

oc_version=""
if command -v openclaw &>/dev/null; then
  oc_version=$(openclaw --version 2>/dev/null | grep -oE '[0-9]{4}\.[0-9]+\.[0-9]+' | head -1 || true)
fi

if [[ -z "$oc_version" ]]; then
  # Try npm
  oc_version=$(npm list -g openclaw 2>/dev/null | grep -oE '[0-9]{4}\.[0-9]+\.[0-9]+' | head -1 || true)
fi

if [[ -z "$oc_version" ]]; then
  warning "Could not determine OpenClaw version. Manual check required."
else
  info "OpenClaw version: ${oc_version}"

  # Parse version components: YYYY.M.P
  IFS='.' read -r oc_year oc_minor oc_patch <<< "$oc_version"

  # CVE-2026-25253, CVE-2026-24763, CVE-2026-25157: Fixed in 2026.1.29
  if [[ "$oc_year" -lt 2026 ]]; then
    critical "Version ${oc_version} is VULNERABLE to CVE-2026-25253 (CVSS 8.8), CVE-2026-24763, CVE-2026-25157"
    echo "         Update immediately: npm install -g openclaw@latest"
  elif [[ "$oc_year" -eq 2026 && "$oc_minor" -lt 1 ]]; then
    critical "Version ${oc_version} is VULNERABLE to CVE-2026-25253 (CVSS 8.8), CVE-2026-24763, CVE-2026-25157"
    echo "         Update immediately: npm install -g openclaw@latest"
  elif [[ "$oc_year" -eq 2026 && "$oc_minor" -eq 1 && "$oc_patch" -lt 29 ]]; then
    critical "Version ${oc_version} is VULNERABLE to CVE-2026-25253 (CVSS 8.8), CVE-2026-24763, CVE-2026-25157"
    echo "         Update immediately: npm install -g openclaw@latest"
  else
    pass "Version ${oc_version} includes CVE-2026-25253/24763/25157 patches"
  fi

  # Check for safety scanner (v2026.2.6+)
  if [[ "$oc_year" -eq 2026 && "$oc_minor" -ge 2 && "$oc_patch" -ge 6 ]] || [[ "$oc_year" -gt 2026 ]] || [[ "$oc_year" -eq 2026 && "$oc_minor" -gt 2 ]]; then
    pass "Version includes skill/plugin safety scanner (v2026.2.6+)"
  else
    warning "Version ${oc_version} lacks skill safety scanner. Recommend upgrading to >= 2026.2.6"
  fi
fi

# --- 2. File Permissions [NIST: Protect] ---
header "2. File & Directory Permissions"

check_perms() {
  local path="$1"
  local expected="$2"
  local label="$3"

  if [[ ! -e "$path" ]]; then
    info "${label}: path does not exist (${path})"
    return
  fi

  local actual
  if [[ "$(uname)" == "Darwin" ]]; then
    actual=$(stat -f '%Lp' "$path" 2>/dev/null || echo "???")
  else
    actual=$(stat -c '%a' "$path" 2>/dev/null || echo "???")
  fi

  if [[ "$actual" == "$expected" ]]; then
    pass "${label}: permissions ${actual} (expected ${expected})"
  else
    if [[ "$actual" =~ ^[0-7]*[4567][0-7]$ ]] || [[ "$actual" == "777" ]] || [[ "$actual" == "755" && "$expected" == "700" ]]; then
      critical "${label}: permissions ${actual} (expected ${expected}) — others/group can access"
    else
      warning "${label}: permissions ${actual} (expected ${expected})"
    fi
  fi
}

check_perms "${STATE_DIR}" "700" "State directory (~/.openclaw)"
check_perms "${CONFIG_FILE}" "600" "Config file (openclaw.json)"

# Check credential files
if [[ -d "${STATE_DIR}/credentials" ]]; then
  while IFS= read -r -d '' cred_file; do
    check_perms "$cred_file" "600" "Credential: $(basename "$cred_file")"
  done < <(find "${STATE_DIR}/credentials" -type f -print0 2>/dev/null)
fi

# Check agent auth profiles
while IFS= read -r -d '' auth_file; do
  check_perms "$auth_file" "600" "Auth profile: ${auth_file#${STATE_DIR}/}"
done < <(find "${STATE_DIR}/agents" -name "auth-profiles.json" -print0 2>/dev/null)

# Check .env file
if [[ -f "${STATE_DIR}/.env" ]]; then
  check_perms "${STATE_DIR}/.env" "600" "Environment file (.env)"
fi

# --- 3. Credential Exposure in Config [OWASP ASI05] ---
header "3. Credential Exposure in Config"

if [[ -f "${CONFIG_FILE}" ]]; then
  # Check for inline tokens/keys (not env var references)
  if echo "$config_content" | grep -qiE '"(api[_-]?key|token|secret|password)"\s*:\s*"[^$][^"]{8,}"'; then
    critical "Hardcoded secrets found in config file. Use environment variables instead."
    echo "         Matches:"
    echo "$config_content" | grep -inE '"(api[_-]?key|token|secret|password)"\s*:\s*"[^$][^"]{8,}"' | head -5 | while read -r line; do
      echo "           $line"
    done
  else
    pass "No obvious hardcoded secrets in config (or using env var references)"
  fi

  # Check for weak/short tokens
  if echo "$config_content" | grep -qE '"token"\s*:\s*"[^"]{1,15}"'; then
    warning "Short token detected (< 16 chars). Use: openssl rand -hex 32"
  fi
fi

# --- 4. Network Binding & Auth [OWASP ASI08, NIST: Protect] ---
header "4. Network Binding & Authentication"

if [[ -f "${CONFIG_FILE}" ]]; then
  # Check gateway bind
  bind_value=$(echo "$config_content" | grep -oE '"bind"\s*:\s*"[^"]*"' | head -1 | grep -oE '"[^"]*"$' | tr -d '"' || true)

  if [[ -z "$bind_value" ]] || [[ "$bind_value" == "loopback" ]]; then
    pass "Gateway bind: loopback (local only)"
  elif [[ "$bind_value" == "lan" ]]; then
    warning "Gateway bind: lan — exposed to local network. Ensure auth token is set and firewall configured."
  elif [[ "$bind_value" == "0.0.0.0" ]] || [[ "$bind_value" == "custom" ]]; then
    critical "Gateway bind: ${bind_value} — publicly exposed! Verify auth + firewall."
  else
    info "Gateway bind: ${bind_value}"
  fi

  # Check auth mode
  auth_mode=$(echo "$config_content" | grep -oE '"mode"\s*:\s*"(token|password)"' | head -1 | grep -oE '(token|password)' || true)
  auth_token=$(echo "$config_content" | grep -oE '"token"\s*:\s*"[^"]*"' | head -1 || true)

  if [[ -n "$auth_mode" ]]; then
    pass "Gateway auth mode: ${auth_mode}"
  else
    if [[ "$bind_value" != "loopback" ]] && [[ -n "$bind_value" ]]; then
      critical "No auth mode configured with non-loopback bind!"
    else
      info "No auth mode configured (acceptable for loopback)"
    fi
  fi
fi

# --- 5. DM Policy & Group Access [OWASP ASI01, ASI08] ---
header "5. DM Policy & Group Access Control"

if [[ -f "${CONFIG_FILE}" ]]; then
  # Check for open DM policies
  if echo "$config_content" | grep -qE '"dmPolicy"\s*:\s*"open"'; then
    critical "DM policy set to 'open' — anyone can message the bot! Use 'pairing' or 'allowlist'."
  elif echo "$config_content" | grep -qE '"dmPolicy"\s*:\s*"pairing"'; then
    pass "DM policy: pairing (unknown senders need approval)"
  elif echo "$config_content" | grep -qE '"dmPolicy"\s*:\s*"allowlist"'; then
    pass "DM policy: allowlist (only approved senders)"
  elif echo "$config_content" | grep -qE '"dmPolicy"\s*:\s*"disabled"'; then
    pass "DM policy: disabled"
  else
    info "DM policy not explicitly set (defaults to 'pairing')"
  fi

  # Check for wildcard allowFrom
  if echo "$config_content" | grep -qE '"allowFrom"\s*:\s*\[\s*"\*"\s*\]'; then
    critical "allowFrom contains wildcard '*' — allows all senders!"
  fi

  # Check requireMention for groups
  if echo "$config_content" | grep -qE '"requireMention"\s*:\s*false'; then
    warning "Some groups have requireMention: false — bot responds to all messages in those groups."
  fi
fi

# --- 6. Sandbox & Tool Policies [OWASP ASI02, ASI09] ---
header "6. Sandbox & Tool Policies"

if [[ -f "${CONFIG_FILE}" ]]; then
  # Sandbox mode
  sandbox_mode=$(echo "$config_content" | grep -oE '"mode"\s*:\s*"(off|non-main|all)"' | head -1 | grep -oE '(off|non-main|all)' || true)
  if [[ "$sandbox_mode" == "off" ]]; then
    warning "Sandbox mode: off — all sessions run unsandboxed on host."
  elif [[ "$sandbox_mode" == "non-main" ]]; then
    pass "Sandbox mode: non-main (non-owner sessions sandboxed)"
  elif [[ "$sandbox_mode" == "all" ]]; then
    pass "Sandbox mode: all (maximum isolation)"
  else
    info "Sandbox mode not explicitly set"
  fi

  # Check for elevated tools
  if echo "$config_content" | grep -qE '"elevated"\s*:\s*\{' && echo "$config_content" | grep -qE '"enabled"\s*:\s*true'; then
    warning "Elevated mode enabled — agents can execute on host. Check allowFrom restrictions."
  fi

  # Check tool profile
  tool_profile=$(echo "$config_content" | grep -oE '"profile"\s*:\s*"(minimal|coding|messaging|full)"' | head -1 | grep -oE '(minimal|coding|messaging|full)' || true)
  if [[ "$tool_profile" == "full" ]]; then
    warning "Tool profile: full — all tools enabled. Consider restricting for untrusted channels."
  elif [[ -n "$tool_profile" ]]; then
    pass "Tool profile: ${tool_profile}"
  fi

  # Check docker network for sandbox
  if echo "$config_content" | grep -qE '"network"\s*:\s*"(bridge|host)"'; then
    warning "Sandbox docker network is not 'none' — containers have network access."
  fi
fi

# --- 7. Log Redaction [OWASP ASI05] ---
header "7. Logging & Redaction"

if [[ -f "${CONFIG_FILE}" ]]; then
  if echo "$config_content" | grep -qE '"redactSensitive"\s*:\s*"off"'; then
    warning "Log redaction is OFF — sensitive data may appear in logs."
  elif echo "$config_content" | grep -qE '"redactSensitive"\s*:\s*"tools"'; then
    pass "Log redaction: tools (tool output redacted)"
  else
    info "Log redaction not explicitly set"
  fi
fi

# Check log file permissions
LOG_DIR="${OPENCLAW_LOG_DIR:-/tmp/openclaw}"
if [[ -d "$LOG_DIR" ]]; then
  log_perms=$(stat -f '%Lp' "$LOG_DIR" 2>/dev/null || stat -c '%a' "$LOG_DIR" 2>/dev/null || echo "???")
  if [[ "$log_perms" =~ [4567][0-7][0-7] ]] && [[ "$log_perms" != "700" ]]; then
    warning "Log directory ${LOG_DIR} permissions: ${log_perms} (consider 700)"
  else
    pass "Log directory permissions: ${log_perms}"
  fi
fi

# --- 8. Plugins & Extensions [OWASP ASI06] ---
header "8. Plugins & Extensions"

EXTENSIONS_DIR="${STATE_DIR}/extensions"
if [[ -d "$EXTENSIONS_DIR" ]]; then
  plugin_count=$(find "$EXTENSIONS_DIR" -maxdepth 1 -type d | wc -l | tr -d ' ')
  ((plugin_count--)) || true  # subtract the directory itself
  if [[ $plugin_count -gt 0 ]]; then
    warning "${plugin_count} plugin(s) installed. Review each for trust:"
    find "$EXTENSIONS_DIR" -maxdepth 1 -type d | tail -n +2 | while read -r p; do
      echo "           - $(basename "$p")"
    done
  else
    pass "No plugins installed"
  fi
else
  pass "No extensions directory found"
fi

# --- 9. Skill Supply Chain Security [OWASP ASI06] ---
header "9. Skill Supply Chain Security"

SKILLS_DIR="${STATE_DIR}/skills"
skills_checked=0
skills_suspicious=0

if [[ -d "$SKILLS_DIR" ]]; then
  skill_count=$(find "$SKILLS_DIR" -maxdepth 1 -type d | wc -l | tr -d ' ')
  ((skill_count--)) || true
  if [[ $skill_count -gt 0 ]]; then
    info "${skill_count} skill(s) installed in ${SKILLS_DIR}"

    # Scan each skill for suspicious patterns
    while IFS= read -r -d '' skill_file; do
      ((skills_checked++)) || true

      # Check for data exfiltration patterns (curl/wget to external hosts)
      if grep -qE '(curl|wget|nc|ncat)\s+.*(http|ftp|tcp)' "$skill_file" 2>/dev/null; then
        critical "Suspicious exfiltration pattern in skill: ${skill_file#${STATE_DIR}/}"
        ((skills_suspicious++)) || true
      fi

      # Check for obfuscated commands (base64 decode + exec)
      if grep -qE '(base64\s+(-d|--decode)|eval\s+\$|exec\s+\$)' "$skill_file" 2>/dev/null; then
        critical "Obfuscated execution pattern in skill: ${skill_file#${STATE_DIR}/}"
        ((skills_suspicious++)) || true
      fi

      # Check for reverse shell patterns
      if grep -qE '(/dev/tcp/|mkfifo|bash\s+-i\s+>&|nc\s+-e)' "$skill_file" 2>/dev/null; then
        critical "Reverse shell pattern in skill: ${skill_file#${STATE_DIR}/}"
        ((skills_suspicious++)) || true
      fi

      # Check for environment variable stealing
      if grep -qE '(printenv|env\s*>|echo\s+\$[A-Z_].*\|.*(curl|wget|nc))' "$skill_file" 2>/dev/null; then
        warning "Env variable exfiltration pattern in skill: ${skill_file#${STATE_DIR}/}"
        ((skills_suspicious++)) || true
      fi

    done < <(find "$SKILLS_DIR" -type f \( -name "*.sh" -o -name "*.py" -o -name "*.js" -o -name "*.md" \) -print0 2>/dev/null)

    if [[ $skills_suspicious -eq 0 ]]; then
      pass "No suspicious patterns found in ${skills_checked} skill file(s)"
    else
      critical "${skills_suspicious} suspicious pattern(s) found. Run: openclaw skills scan"
    fi

    # Check if safety scanner is available
    if command -v openclaw &>/dev/null; then
      if openclaw skills scan --help &>/dev/null 2>&1; then
        info "Safety scanner available. Run: openclaw skills scan <skill-path>"
      fi
    fi
  else
    pass "No skills installed"
  fi
else
  info "No skills directory found"
fi

# --- 10. Control UI Security [CVE-2026-25253] ---
header "10. Control UI Security"

if [[ -f "${CONFIG_FILE}" ]]; then
  if echo "$config_content" | grep -qE '"allowInsecureAuth"\s*:\s*true'; then
    warning "Control UI allowInsecureAuth is TRUE — device pairing bypassed, token-only auth."
  fi

  if echo "$config_content" | grep -qE '"dangerouslyDisableDeviceAuth"\s*:\s*true'; then
    critical "Control UI device auth DISABLED — severe security downgrade!"
    echo "         Set gateway.controlUi.dangerouslyDisableDeviceAuth: false"
  fi
fi

# --- 11. Reverse Proxy Configuration [CVE-2026-24763] ---
header "11. Reverse Proxy Configuration"

if [[ -f "${CONFIG_FILE}" ]]; then
  if echo "$config_content" | grep -q '"trustedProxies"'; then
    info "Trusted proxies configured — verify proxy overwrites (not appends) X-Forwarded-For"
    echo "         Test: curl -H 'X-Forwarded-For: 127.0.0.1' http://proxy:port/health"
    echo "         If this bypasses auth, your proxy is misconfigured (CVE-2026-24763 vector)"
  fi

  # Check if using non-loopback bind without trusted proxies (common with nginx/caddy)
  bind_value=$(echo "$config_content" | grep -oE '"bind"\s*:\s*"[^"]*"' | head -1 | grep -oE '"[^"]*"$' | tr -d '"' || true)
  if [[ "$bind_value" == "lan" || "$bind_value" == "custom" || "$bind_value" == "0.0.0.0" ]]; then
    if ! echo "$config_content" | grep -q '"trustedProxies"'; then
      warning "Non-loopback bind without trustedProxies — if behind a reverse proxy, configure trustedProxies to prevent auth bypass"
    fi
  fi
fi

# --- 12. Gateway Process [NIST: Detect] ---
header "12. Gateway Process"

gateway_pid=$(pgrep -f "openclaw.*gateway" 2>/dev/null || true)
if [[ -n "$gateway_pid" ]]; then
  info "Gateway process running (PID: ${gateway_pid})"

  # Check listening ports
  if command -v lsof &>/dev/null; then
    listening=$(lsof -i -P -n 2>/dev/null | grep "$gateway_pid" | grep LISTEN || true)
    if [[ -n "$listening" ]]; then
      echo "         Listening on:"
      echo "$listening" | while read -r line; do
        echo "           $line"
        if echo "$line" | grep -qE '\*:|\b0\.0\.0\.0:'; then
          critical "Gateway listening on all interfaces (0.0.0.0)!"
        fi
      done
    fi
  fi

  # Check for unexpected outbound connections (exfiltration detection)
  if command -v lsof &>/dev/null; then
    outbound=$(lsof -i -P -n 2>/dev/null | grep "$gateway_pid" | grep ESTABLISHED | grep -v "127.0.0.1" | grep -v "::1" || true)
    if [[ -n "$outbound" ]]; then
      outbound_count=$(echo "$outbound" | wc -l | tr -d ' ')
      info "${outbound_count} outbound connection(s) from gateway — review for legitimacy"
    fi
  fi
else
  info "Gateway process not currently running"
fi

# --- 13. Sensitive Files in Synced Folders [NIST: Protect] ---
header "13. Sensitive Data Location Check"

# Check if state dir is inside common synced folders
synced_dirs=("$HOME/Dropbox" "$HOME/Google Drive" "$HOME/OneDrive" "$HOME/iCloud" "$HOME/Library/Mobile Documents")
for sync_dir in "${synced_dirs[@]}"; do
  if [[ "${STATE_DIR}" == "${sync_dir}"* ]]; then
    critical "OpenClaw state directory is inside a synced folder: ${sync_dir}"
    echo "         Move to a non-synced location to prevent credential exposure."
  fi
done
pass "State directory not in common synced folders"

# --- 14. Session Transcript Quick Scan [OWASP ASI05] ---
header "14. Session Transcript Secret Scan (sampling)"

secret_patterns='(sk-[a-zA-Z0-9]{20,}|sk-ant-[a-zA-Z0-9_-]{20,}|AKIA[A-Z0-9]{16}|ghp_[a-zA-Z0-9]{36}|xoxb-[0-9]+-[a-zA-Z0-9]+|-----BEGIN (RSA |EC )?PRIVATE KEY-----|AIza[A-Za-z0-9_-]{35})'
leaked_count=0

# Sample up to 10 recent session files
sample_count=0
while IFS= read -r -d '' session_file; do
  if [[ $sample_count -ge 10 ]]; then
    break
  fi
  if grep -qE "$secret_patterns" "$session_file" 2>/dev/null; then
    ((leaked_count++)) || true
    warning "Potential secret found in transcript: ${session_file#${STATE_DIR}/}"
  fi
  ((sample_count++)) || true
done < <(find "${STATE_DIR}/agents" -name "*.jsonl" -type f -print0 2>/dev/null)

if [[ $leaked_count -eq 0 ]]; then
  pass "No obvious secrets found in sampled session transcripts"
fi

# --- Summary ---
header "Audit Summary"
echo ""
echo "  $(red   "${CRITICAL} CRITICAL")"
echo "  $(yellow "${WARNING} Warnings")"
echo "  $(blue   "${INFO} Informational")"
echo "  $(green  "${PASS} Passed")"
echo ""
echo "  Framework: OWASP Agentic Top 10 (ASI01-ASI10) + NIST CSF"
echo "  CVE Coverage: CVE-2026-25253, CVE-2026-24763, CVE-2026-25157"
echo ""

if [[ $CRITICAL -gt 0 ]]; then
  red "ACTION REQUIRED: Fix critical issues before continuing."
  echo ""
  echo "  Quick fixes:"
  echo "    1. Update: npm install -g openclaw@latest"
  echo "    2. Permissions: chmod 700 ~/.openclaw && chmod 600 ~/.openclaw/openclaw.json"
  echo "    3. Rotate tokens: openssl rand -hex 32"
  echo "    4. Scan skills: openclaw skills scan"
  exit 2
elif [[ $WARNING -gt 0 ]]; then
  yellow "Review warnings and harden where possible."
  exit 0
else
  green "All checks passed. Installation looks secure."
  exit 0
fi
