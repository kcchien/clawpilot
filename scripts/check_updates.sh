#!/usr/bin/env bash
# check_updates.sh — Check if clawpilot skill references are stale
# Exit codes: 0 = up-to-date, 1 = stale (needs update), 2 = error
# Output: JSON-like status for Claude to parse

set -euo pipefail

SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
MARKER_FILE="$SKILL_DIR/.last_update_check"
STALE_DAYS="${1:-7}"

now=$(date +%s)

# Check marker file
if [[ -f "$MARKER_FILE" ]]; then
    last_check=$(cat "$MARKER_FILE" | head -1)
    last_version=$(sed -n '2p' "$MARKER_FILE" 2>/dev/null || echo "unknown")
    age_seconds=$((now - last_check))
    age_days=$((age_seconds / 86400))
else
    age_days=999
    last_version="unknown"
fi

if [[ $age_days -lt $STALE_DAYS ]]; then
    echo "STATUS: UP_TO_DATE"
    echo "LAST_CHECK_DAYS_AGO: $age_days"
    echo "SKILL_VERSION: $last_version"
    exit 0
fi

# Stale — fetch latest release from GitHub API
echo "STATUS: STALE"
echo "LAST_CHECK_DAYS_AGO: $age_days"
echo "SKILL_VERSION: $last_version"

if command -v curl &>/dev/null; then
    latest=$(curl -sf --max-time 10 \
        "https://api.github.com/repos/openclaw/openclaw/releases?per_page=3" 2>/dev/null || echo "FETCH_FAILED")

    if [[ "$latest" != "FETCH_FAILED" ]]; then
        # Extract tag names and publication dates
        echo "---"
        echo "LATEST_RELEASES:"
        echo "$latest" | grep -E '"tag_name"|"published_at"|"name"' | head -9
        echo "---"
    else
        echo "FETCH: FAILED (network or rate limit)"
    fi
else
    echo "FETCH: SKIPPED (curl not available)"
fi

echo ""
echo "ACTION_REQUIRED: Fetch https://github.com/openclaw/openclaw/releases and https://docs.openclaw.ai/llms.txt to check for updates."
echo "After updating references, run: bash $SKILL_DIR/scripts/mark_updated.sh <version>"

exit 1
