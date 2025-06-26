#!/bin/bash
# Script to detect the correct ITGMania installation path and version
# Usage: ./detect-itgmania-path.sh [--path-only|--version-only]

set -e

# Parse mode, stripping -- prefix if present
RAW_MODE="${1:-both}"
MODE="${RAW_MODE#--}"

# Try common installation paths
POSSIBLE_PATHS=(
    "/usr/local/itgmania"
    "/usr/local/itgmania-1.0"
    "/usr/local/itgmania-1.1"
    "/usr/local/itgmania-1.2"
    "/usr/games/itgmania"
)

ITGMANIA_PATH=""
ITGMANIA_BINARY=""

# Find the actual installation
for path in "${POSSIBLE_PATHS[@]}"; do
    if [ -d "${path}" ] && [ -x "${path}/itgmania" ]; then
        ITGMANIA_PATH="${path}"
        ITGMANIA_BINARY="${path}/itgmania"
        break
    fi
done

if [ -z "${ITGMANIA_PATH}" ]; then
    echo "Error: Could not find ITGMania installation" >&2
    exit 1
fi

# Extract version information
if [ "${MODE}" = "path-only" ]; then
    echo "${ITGMANIA_PATH}"
    exit 0
fi

# Try to get version from binary
VERSION_OUTPUT=""
if [ -x "${ITGMANIA_BINARY}" ]; then
    VERSION_OUTPUT=$("${ITGMANIA_BINARY}" --version 2>/dev/null || true)
fi

# Parse version if we got output
VERSION_NUM=""
if [ -n "${VERSION_OUTPUT}" ]; then
    # Extract version from first line, handling formats like "ITGmania1.0.2-git-427484d100"
    VERSION_NUM=$(echo "${VERSION_OUTPUT}" | head -n 1 | sed -E 's/ITGmania([0-9]+\.[0-9]+\.[0-9]+).*/\1/')
fi

# If we couldn't get version from binary, try to infer from path
if [ -z "${VERSION_NUM}" ]; then
    # Try to extract version from path name
    case "${ITGMANIA_PATH}" in
        */itgmania-*)
            VERSION_NUM=$(basename "${ITGMANIA_PATH}" | sed 's/itgmania-//')
            ;;
        */itgmania)
            # Default version if installed in generic path
            VERSION_NUM="1.0"
            ;;
        *)
            VERSION_NUM="1.0"
            ;;
    esac
fi

case "${MODE}" in
    "version-only")
        echo "${VERSION_NUM}"
        ;;
    "both"|*)
        echo "${ITGMANIA_PATH}:${VERSION_NUM}"
        ;;
esac 