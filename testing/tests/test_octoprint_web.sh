#!/bin/bash
set -e

export E2E_SSH_HOST="${1:-localhost}"
export E2E_SSH_PORT="${2:-2222}"
ARTIFACTS_DIR="${3:-}"
source /test/scripts/ssh-helpers.sh
source /test/scripts/browser-helpers.sh

echo "Test: OctoPrint web server is accessible with CONFIG_WIZARD"

OCTOPRINT_READY=0
BODY=""
HTTP_CODE="000"
for i in $(seq 1 120); do
    BODY=$(ssh_cmd "curl -s http://localhost" 2>/dev/null || echo "")
    HTTP_CODE=$(ssh_cmd "curl -s -o /dev/null -w '%{http_code}' http://localhost" 2>/dev/null || echo "000")

    if [ "$HTTP_CODE" = "200" ]; then
        if echo "$BODY" | grep -q "CONFIG_WIZARD"; then
            OCTOPRINT_READY=1
            break
        elif echo "$BODY" | grep -q "starting up\|still starting"; then
            printf "S"
        else
            printf "?"
        fi
    else
        printf "."
    fi
    sleep 5
done
echo ""

if [ "$OCTOPRINT_READY" -eq 0 ]; then
    echo "  FAIL: OctoPrint CONFIG_WIZARD did not appear within 600s"
    echo "  Last HTTP code: $HTTP_CODE"
    echo "  Last body (first 200 chars): $(echo "$BODY" | head -c 200)"
    exit 1
fi

echo "  OctoPrint CONFIG_WIZARD is loaded (HTTP 200)"

if [ -n "$ARTIFACTS_DIR" ]; then
    echo "$BODY" > "$ARTIFACTS_DIR/octoprint.html"
    echo "  Saved wizard HTML to $ARTIFACTS_DIR/octoprint.html"
fi

if ! echo "$BODY" | grep -q "OctoPrint"; then
    echo "  FAIL: Wizard page did not contain 'OctoPrint'"
    exit 1
fi

HTTP_PORT="${QEMU_HTTP_PORT:-8080}"
if [ -n "$ARTIFACTS_DIR" ] && find_headless_browser >/dev/null; then
    echo "  Taking wizard screenshot via headless Chrome (with OCR retry)..."
    if headless_screenshot "http://localhost:${HTTP_PORT}" \
            "$ARTIFACTS_DIR/screenshot.png" \
            "wizard|access.control|setup"; then
        echo "  Screenshot captured with wizard visible"
    elif [ -f "$ARTIFACTS_DIR/screenshot.png" ]; then
        echo "  WARNING: Wizard not detected via OCR after retries, keeping last screenshot"
    fi

    if [ -n "$HEADLESS_OCR_TEXT" ]; then
        echo "$HEADLESS_OCR_TEXT" > "$ARTIFACTS_DIR/screenshot-ocr.txt"
    fi
fi

echo "  PASS: OctoPrint wizard page verified"
exit 0
