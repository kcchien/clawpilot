#!/usr/bin/env bash
# OpenClaw Configuration Inspector
# Parses openclaw.json and reports security-relevant settings with recommendations.
# Usage: bash config_inspector.sh [--state-dir PATH] [--section SECTION]
#
# Sections: gateway, channels, agents, tools, sessions, logging, all (default)
#
# NOTE: This script uses heuristic grep-based parsing of JSON5.
# For authoritative results, prefer: openclaw config get
# Limitations: unquoted keys may be missed; ambiguous keys (e.g. "mode")
# are matched with context-aware helpers but may still be imprecise.

set -euo pipefail

STATE_DIR="${HOME}/.openclaw"
SECTION="all"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --state-dir) STATE_DIR="$2"; shift 2 ;;
    --section)   SECTION="$2"; shift 2 ;;
    *) echo "Unknown arg: $1"; exit 1 ;;
  esac
done

CONFIG_FILE="${STATE_DIR}/openclaw.json"

red()    { printf '\033[0;31m%s\033[0m\n' "$*"; }
yellow() { printf '\033[0;33m%s\033[0m\n' "$*"; }
green()  { printf '\033[0;32m%s\033[0m\n' "$*"; }
blue()   { printf '\033[0;34m%s\033[0m\n' "$*"; }
bold()   { printf '\033[1m%s\033[0m\n' "$*"; }

header() {
  echo ""
  bold "=== $* ==="
}

if [[ ! -f "$CONFIG_FILE" ]]; then
  red "Config file not found: ${CONFIG_FILE}"
  exit 1
fi

echo "OpenClaw Configuration Inspector"
echo "Config: ${CONFIG_FILE}"
echo "Date:   $(date -u '+%Y-%m-%dT%H:%M:%SZ')"

# Read config content
CONFIG=$(cat "$CONFIG_FILE")

# Helper: extract value by key pattern (heuristic grep-based, works for quoted JSON5 keys)
# Supports both quoted and unquoted keys.
extract() {
  local val
  val=$(echo "$CONFIG" | grep -oE "\"?$1\"?\s*:\s*\"[^\"]*\"" | head -1 | grep -oE '"[^"]*"$' | tr -d '"' || true)
  echo "$val"
}

extract_bool() {
  echo "$CONFIG" | grep -oE "\"?$1\"?\s*:\s*(true|false)" | head -1 | grep -oE '(true|false)' || true
}

extract_num() {
  echo "$CONFIG" | grep -oE "\"?$1\"?\s*:\s*[0-9]+" | head -1 | grep -oE '[0-9]+$' || true
}

# Context-aware extract: search for a key within N lines after a parent key
# Usage: extract_under "parent_key" "child_key" [lines_after]
extract_under() {
  local parent="$1" child="$2" lines="${3:-10}"
  echo "$CONFIG" | grep -A "$lines" "\"?${parent}\"?\s*:" | grep -oE "\"?${child}\"?\s*:\s*\"[^\"]*\"" | head -1 | grep -oE '"[^"]*"$' | tr -d '"' || true
}

extract_bool_under() {
  local parent="$1" child="$2" lines="${3:-10}"
  echo "$CONFIG" | grep -A "$lines" "\"?${parent}\"?\s*:" | grep -oE "\"?${child}\"?\s*:\s*(true|false)" | head -1 | grep -oE '(true|false)' || true
}

# --- Gateway ---
inspect_gateway() {
  header "Gateway Configuration"

  local bind=$(extract_under "gateway" "bind")
  local port=$(echo "$CONFIG" | grep -A 10 "\"?gateway\"?\s*:" | grep -oE "\"?port\"?\s*:\s*[0-9]+" | head -1 | grep -oE '[0-9]+$' || true)
  local auth_mode=$(extract_under "auth" "mode" 5)
  local mode=$(extract_under "gateway" "mode")

  echo "  Mode:      ${mode:-local (default)}"
  echo "  Bind:      ${bind:-loopback (default)}"
  echo "  Port:      ${port:-18789 (default)}"
  echo "  Auth mode: ${auth_mode:-not set}"

  # Security assessment
  if [[ "${bind}" == "lan" || "${bind}" == "0.0.0.0" || "${bind}" == "custom" ]]; then
    red "  ⚠ Non-loopback bind detected. Ensure auth is configured."
    if [[ -z "$auth_mode" ]]; then
      red "  ⚠ NO AUTH configured with non-loopback bind — CRITICAL!"
    fi
  else
    green "  ✓ Loopback bind (secure default)"
  fi

  # Check Tailscale auth
  local allow_ts=$(extract_bool "allowTailscale")
  if [[ "$allow_ts" == "true" ]]; then
    yellow "  ⚠ Tailscale identity auth enabled. Only use with trusted tailnets."
  fi

  # Check trusted proxies
  if echo "$CONFIG" | grep -q "trustedProxies"; then
    blue "  ℹ Trusted proxies configured (reverse proxy setup)"
  fi
}

# --- Channels ---
inspect_channels() {
  header "Channel Configuration"

  # List all channels found in config
  local channels=$(echo "$CONFIG" | grep -oE '"(whatsapp|telegram|discord|slack|imessage|signal|googlechat|msteams|mattermost|line|matrix|feishu|zalo|zalouser)"\s*:' | tr -d '":' | tr -d ' ' || true)

  if [[ -z "$channels" ]]; then
    blue "  ℹ No channels explicitly configured"
    return
  fi

  for ch in $channels; do
    echo ""
    bold "  Channel: ${ch}"

    # DM policy
    # Search within channel block (simplified — looks for dmPolicy near channel name)
    local dm_policy=$(echo "$CONFIG" | grep -A 20 "\"${ch}\"" | grep -oE '"dmPolicy"\s*:\s*"[^"]*"' | head -1 | grep -oE '"[^"]*"$' | tr -d '"' || true)

    if [[ "$dm_policy" == "open" ]]; then
      red "    ⚠ DM policy: open — ANYONE can message this bot!"
    elif [[ "$dm_policy" == "pairing" ]]; then
      green "    ✓ DM policy: pairing"
    elif [[ "$dm_policy" == "allowlist" ]]; then
      green "    ✓ DM policy: allowlist"
    elif [[ "$dm_policy" == "disabled" ]]; then
      green "    ✓ DM policy: disabled"
    else
      blue "    ℹ DM policy: not set (defaults to pairing)"
    fi

    # Check for tokens in config (not env var)
    if echo "$CONFIG" | grep -A 10 "\"${ch}\"" | grep -qE '"(botToken|token)"\s*:\s*"[^$][^"]{5,}"'; then
      red "    ⚠ Token appears hardcoded. Use environment variable instead."
    fi
  done
}

# --- Agents ---
inspect_agents() {
  header "Agent Configuration"

  # Sandbox
  local sandbox_mode=$(echo "$CONFIG" | grep -oE '"mode"\s*:\s*"(off|non-main|all)"' | head -1 | grep -oE '(off|non-main|all)' || true)
  local workspace_access=$(extract "workspaceAccess")
  local max_concurrent=$(extract_num "maxConcurrent")
  local timeout=$(extract_num "timeoutSeconds")

  echo "  Sandbox mode:      ${sandbox_mode:-not set (defaults to non-main)}"
  echo "  Workspace access:  ${workspace_access:-not set (defaults to none)}"
  echo "  Max concurrent:    ${max_concurrent:-1 (default)}"
  echo "  Timeout (seconds): ${timeout:-600 (default)}"

  if [[ "$sandbox_mode" == "off" ]]; then
    yellow "  ⚠ Sandbox disabled — all sessions execute on host"
  elif [[ "$sandbox_mode" == "all" ]]; then
    green "  ✓ All sessions sandboxed"
  fi

  if [[ "$workspace_access" == "rw" ]]; then
    yellow "  ⚠ Workspace access: rw — sandboxed agents can modify host files"
  fi

  # List agents
  local agent_ids=$(echo "$CONFIG" | grep -oE '"id"\s*:\s*"[^"]*"' | grep -oE '"[^"]*"$' | tr -d '"' || true)
  if [[ -n "$agent_ids" ]]; then
    echo ""
    echo "  Defined agents:"
    for agent_id in $agent_ids; do
      echo "    - ${agent_id}"
      # Check agent-specific sandbox
      local agent_dir="${STATE_DIR}/agents/${agent_id}"
      if [[ -d "$agent_dir" ]]; then
        if [[ -f "${agent_dir}/agent/auth-profiles.json" ]]; then
          green "      ✓ Has auth profiles"
        fi
        local session_count=$(find "${agent_dir}/sessions" -name "*.jsonl" 2>/dev/null | wc -l | tr -d ' ')
        echo "      Sessions: ${session_count}"
      fi
    done
  fi
}

# --- Tools ---
inspect_tools() {
  header "Tool Configuration"

  local tool_profile=$(echo "$CONFIG" | grep -oE '"profile"\s*:\s*"(minimal|coding|messaging|full)"' | head -1 | grep -oE '(minimal|coding|messaging|full)' || true)
  echo "  Profile: ${tool_profile:-not set}"

  if [[ "$tool_profile" == "full" ]]; then
    yellow "  ⚠ Full tool profile — all tools enabled"
  fi

  # Check denied tools
  if echo "$CONFIG" | grep -q '"deny"'; then
    echo "  Denied tools found (good — explicit denials)"
  fi

  # Check elevated
  local elevated=$(extract_bool_under "elevated" "enabled" 5)
  if [[ "$elevated" == "true" ]]; then
    yellow "  ⚠ Elevated mode enabled — host-level execution available"
    # Check allowFrom
    if echo "$CONFIG" | grep -A 5 '"elevated"' | grep -q '"allowFrom"'; then
      green "    ✓ allowFrom restriction configured"
    else
      red "    ⚠ No allowFrom restriction on elevated mode!"
    fi
  fi

  # Check web tools
  if echo "$CONFIG" | grep -q '"web_fetch"' || echo "$CONFIG" | grep -q '"web"'; then
    blue "  ℹ Web tools configured (search/fetch)"
  fi

  # Check agent-to-agent
  local a2a=$(echo "$CONFIG" | grep -A 3 '"agentToAgent"' | grep -oE '(true|false)' | head -1 || true)
  if [[ "$a2a" == "true" ]]; then
    yellow "  ⚠ Agent-to-agent messaging enabled"
  fi
}

# --- Sessions ---
inspect_sessions() {
  header "Session Configuration"

  local scope=$(extract_under "session" "scope")
  local dm_scope=$(extract_under "session" "dmScope")
  local reset_mode=$(extract_under "reset" "mode" 5)

  echo "  Scope:      ${scope:-per-sender (default)}"
  echo "  DM scope:   ${dm_scope:-not set}"
  echo "  Reset mode: ${reset_mode:-daily (default)}"

  # Check reset triggers
  if echo "$CONFIG" | grep -q "resetTriggers"; then
    green "  ✓ Reset triggers configured"
  fi

  # Count total sessions
  local total_sessions=$(find "${STATE_DIR}/agents" -name "*.jsonl" 2>/dev/null | wc -l | tr -d ' ')
  echo "  Total session files: ${total_sessions}"

  # Check session file sizes
  local large_sessions=$(find "${STATE_DIR}/agents" -name "*.jsonl" -size +10M 2>/dev/null | wc -l | tr -d ' ')
  if [[ $large_sessions -gt 0 ]]; then
    yellow "  ⚠ ${large_sessions} session file(s) >10MB — consider pruning old sessions"
  fi
}

# --- Logging ---
inspect_logging() {
  header "Logging Configuration"

  local log_level=$(extract "level")
  local console_level=$(extract "consoleLevel")
  local redact=$(extract "redactSensitive")

  echo "  File log level:    ${log_level:-info (default)}"
  echo "  Console log level: ${console_level:-info (default)}"
  echo "  Redact sensitive:  ${redact:-not set}"

  if [[ "$redact" == "off" ]]; then
    yellow "  ⚠ Sensitive redaction is OFF — secrets may appear in logs"
  elif [[ "$redact" == "tools" ]]; then
    green "  ✓ Tool output redacted in logs"
  fi

  # Check log files
  local log_dir="/tmp/openclaw"
  if [[ -d "$log_dir" ]]; then
    local log_count=$(find "$log_dir" -name "*.log" 2>/dev/null | wc -l | tr -d ' ')
    local log_size=$(du -sh "$log_dir" 2>/dev/null | cut -f1)
    echo "  Log files: ${log_count} (${log_size})"

    local old_logs=$(find "$log_dir" -name "*.log" -mtime +30 2>/dev/null | wc -l | tr -d ' ')
    if [[ $old_logs -gt 0 ]]; then
      yellow "  ⚠ ${old_logs} log file(s) older than 30 days — consider cleanup"
    fi
  fi
}

# --- Run sections ---
case "$SECTION" in
  gateway)  inspect_gateway ;;
  channels) inspect_channels ;;
  agents)   inspect_agents ;;
  tools)    inspect_tools ;;
  sessions) inspect_sessions ;;
  logging)  inspect_logging ;;
  all)
    inspect_gateway
    inspect_channels
    inspect_agents
    inspect_tools
    inspect_sessions
    inspect_logging
    ;;
  *) red "Unknown section: ${SECTION}"; exit 1 ;;
esac

echo ""
echo "Done."
