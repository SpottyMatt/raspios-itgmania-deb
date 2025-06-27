#!/bin/bash
# Script to extract version, hash, and date from ITGMania binary
# Usage: ./extract-version-from-binary.sh <binary_path> [--major-minor-only|--hash-only|--date-only|--version-hash|--version-hash-date]

set -e

BINARY_PATH="$1"
MODE="${2:-full}"

if [ -z "$BINARY_PATH" ]; then
    echo "Usage: $0 <binary_path> [--major-minor-only|--hash-only|--date-only|--version-hash|--version-hash-date]" >&2
    exit 1
fi

if [ ! -x "$BINARY_PATH" ]; then
    echo "Error: Binary not found or not executable: $BINARY_PATH" >&2
    exit 1
fi

# Try to get version from binary
VERSION_OUTPUT=""
VERSION_OUTPUT=$("$BINARY_PATH" --version 2>/dev/null || true)

if [ -z "$VERSION_OUTPUT" ]; then
    echo "Error: Could not get version from binary: $BINARY_PATH" >&2
    exit 1
fi

# Extract version from first line, handling formats like "ITGmania1.0.2-git-427484d100"
VERSION_NUM=$(echo "$VERSION_OUTPUT" | head -n 1 | sed -E 's/ITGmania([0-9]+\.[0-9]+\.[0-9]+).*/\1/')

# Extract hash from first line after "-git-"
HASH=$(echo "$VERSION_OUTPUT" | head -n 1 | sed -E 's/.*-git-([a-f0-9]+).*/\1/')

# Extract date from second line "Compiled 20250624 @ 00:32:41"
DATE=$(echo "$VERSION_OUTPUT" | head -n 2 | tail -n 1 | sed -E 's/.*Compiled ([0-9]{8}).*/\1/')

if [ -z "$VERSION_NUM" ]; then
    echo "Error: Could not parse version from output: $VERSION_OUTPUT" >&2
    exit 1
fi

case "$MODE" in
    "--major-minor-only")
        # Extract just major.minor (e.g., "1.0" from "1.0.2")
        echo "$VERSION_NUM" | cut -d. -f1-2
        ;;
    "--hash-only")
        echo "$HASH"
        ;;
    "--date-only")
        echo "$DATE"
        ;;
    "--version-hash")
        # Return both space-separated: "1.0.2 427484d100"
        echo "$VERSION_NUM $HASH"
        ;;
    "--version-hash-date")
        # Return all three space-separated: "1.0.2 427484d100 20250624"
        echo "$VERSION_NUM $HASH $DATE"
        ;;
    *)
        echo "$VERSION_NUM"
        ;;
esac
