#!/bin/bash
set -e
export E2E_SSH_HOST="${1:-localhost}"
export E2E_SSH_PORT="${2:-2222}"
ARTIFACTS_DIR="${3:-/output}"
source /test/scripts/ssh-helpers.sh
source /test/scripts/browser-helpers.sh

echo "Waiting for OctoPrint wizard page before capturing..."

WIZARD_READY=0
BODY=""
for i in $(seq 1 24); do
    BODY=$(ssh_cmd "curl -s http://localhost" 2>/dev/null || echo "")
    if echo "$BODY" | grep -q "CONFIG_WIZARD"; then
        WIZARD_READY=1
        echo "$BODY" > "$ARTIFACTS_DIR/octoprint-ui.html"
        echo "  Saved OctoPrint wizard HTML to artifacts (after ${i}x5s)"
        break
    fi
    printf "."
    sleep 5
done
echo ""

if [ "$WIZARD_READY" -eq 0 ]; then
    echo "  WARNING: CONFIG_WIZARD not found after 120s, saving current page"
    if [ -n "$BODY" ]; then
        echo "$BODY" > "$ARTIFACTS_DIR/octoprint-ui.html"
    fi
fi

HTTP_PORT="${QEMU_HTTP_PORT:-8080}"

echo "  Verifying localhost:${HTTP_PORT} is reachable from container..."
HTTP_CHECK=$(curl -s -o /dev/null -w '%{http_code}' "http://localhost:${HTTP_PORT}" 2>/dev/null || echo "000")
echo "  HTTP status from container: ${HTTP_CHECK}"

if ! find_headless_browser >/dev/null; then
    echo "  WARNING: No usable browser found for screenshot"
    exit 0
fi
echo "  Using $BROWSER_PATH ($("$BROWSER_PATH" --version 2>/dev/null || echo 'unknown'))"

if headless_screenshot "http://localhost:${HTTP_PORT}" \
        "$ARTIFACTS_DIR/screenshot.png" \
        "wizard|access.control|setup"; then
    echo "  Screenshot captured with wizard visible"
elif [ -f "$ARTIFACTS_DIR/screenshot.png" ]; then
    echo "  WARNING: Wizard not detected via OCR after retries, keeping last screenshot"
else
    echo "  WARNING: No valid screenshot produced"
fi

if [ -n "$HEADLESS_OCR_TEXT" ]; then
    echo "$HEADLESS_OCR_TEXT" > "$ARTIFACTS_DIR/screenshot-ocr.txt"
fi
