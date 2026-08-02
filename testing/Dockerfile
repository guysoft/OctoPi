ARG CUSTOMPIOS_TAG=devel
FROM ghcr.io/guysoft/custompios:${CUSTOMPIOS_TAG} AS custompios

FROM ptrsr/pi-ci:latest

ENV LIBGUESTFS_BACKEND=direct

RUN apt-get update && apt-get install -y --no-install-recommends \
    sshpass openssh-client curl socat imagemagick wget gnupg \
    dbus dbus-x11 fonts-liberation tesseract-ocr \
    && wget -q -O - https://dl.google.com/linux/linux_signing_key.pub | gpg --dearmor -o /usr/share/keyrings/google-chrome.gpg \
    && echo "deb [arch=amd64 signed-by=/usr/share/keyrings/google-chrome.gpg] http://dl.google.com/linux/chrome/deb/ stable main" > /etc/apt/sources.list.d/google-chrome.list \
    && apt-get update && apt-get install -y --no-install-recommends google-chrome-stable \
    && rm -rf /var/lib/apt/lists/*

COPY --from=custompios /CustomPiOS/distro_testing/scripts/ /test/scripts/
COPY --from=custompios /CustomPiOS/distro_testing/tests/ /test/tests/

COPY tests/ /test/tests/
COPY hooks/ /test/hooks/

RUN chmod +x /test/scripts/*.sh /test/tests/*.sh; \
    chmod +x /test/hooks/*.sh 2>/dev/null || true

ENTRYPOINT ["/test/scripts/entrypoint.sh"]
