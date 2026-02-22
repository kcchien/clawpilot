#!/usr/bin/env bash
# mark_updated.sh — Record that skill references have been checked/updated
# Usage: bash mark_updated.sh <openclaw-version>
# Example: bash mark_updated.sh 2026.2.13

set -euo pipefail

SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
MARKER_FILE="$SKILL_DIR/.last_update_check"
VERSION="${1:?Usage: mark_updated.sh <openclaw-version>}"

echo "$(date +%s)" > "$MARKER_FILE"
echo "$VERSION" >> "$MARKER_FILE"
echo "Marked clawpilot skill as checked at $(date -u +%Y-%m-%dT%H:%M:%SZ) for OpenClaw v$VERSION"
