#!/bin/bash
set -e
IMAGE_FILE="${1:?Usage: $0 <image.qcow2>}"

export LIBGUESTFS_BACKEND=direct
export LIBGUESTFS_DEBUG=0
export LIBGUESTFS_TRACE=0

echo '=== OctoPi-specific image patches ==='

echo 'Downloading haproxy config for IPv4 patching...'
guestfish -a "$IMAGE_FILE" <<GFEOF
run
mount /dev/sda2 /
download /etc/haproxy/haproxy.cfg /tmp/haproxy.cfg
umount /
GFEOF

echo 'Fixing haproxy for IPv4-only (QEMU has no IPv6)...'
sed -i 's/bind :::80 v4v6/bind *:80/' /tmp/haproxy.cfg
sed -i 's/bind :::443 v4v6/bind *:443/' /tmp/haproxy.cfg

guestfish -a "$IMAGE_FILE" <<GFEOF2
run
mount /dev/sda2 /
upload /tmp/haproxy.cfg /etc/haproxy/haproxy.cfg
umount /
GFEOF2

echo 'OctoPi patches applied'
