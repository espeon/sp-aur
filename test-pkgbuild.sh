#!/bin/bash
# Simple PKGBUILD test harness for Streamplace
set -e

echo "=== Streamplace PKGBUILD Test Harness ==="
echo ""

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

success() { echo -e "${GREEN}✓${NC} $1"; }
error() { echo -e "${RED}✗${NC} $1"; }
info() { echo -e "${YELLOW}→${NC} $1"; }

# Check if we're in the right directory
if [[ ! -f "arch/PKGBUILD" ]]; then
    error "PKGBUILD not found. Run this script from the arch directory."
    exit 1
fi

info "Starting fresh Arch Linux container for testing..."

# Simple approach: run as root, then su to a build user
exec docker run -it --rm \
    -v "$PWD/arch/:/work-copy" \
    -w /work \
    --name "streamplace-test-$(date +%s)" \
    ghcr.io/fwcd/archlinux:latest \
    bash -c '
        echo "=== Setting up Arch Linux test environment ==="

        # copy files to work directory
        cp -r /work-copy/* /work/

        # Update and install dependencies
        pacman -Syu --noconfirm
        pacman -S --needed --noconfirm \
            base-devel git sudo \
            gstreamer gst-plugins-base gst-plugins-good gst-plugins-bad gst-plugins-ugly gst-libav \
            ffmpeg glib2 nodejs openssl systemd \
            go meson ninja gcc pkgconf cmake nasm yasm rust cargo \
            python gettext libxcb make nvm pnpm

        # Create build user (cant use same UID due to volume mount, but thats ok)
        useradd -m -G wheel -s /bin/bash builduser
        echo "%wheel ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

        # Set up Go environment for builduser
        echo "export GOPATH=/tmp/go" >> /home/builduser/.bashrc
        echo "export GOCACHE=/tmp/go-cache" >> /home/builduser/.bashrc
        echo "export GOTMPDIR=/tmp/go-tmp" >> /home/builduser/.bashrc
        mkdir -p /tmp/go /tmp/go-cache /tmp/go-tmp
        chown -R builduser:builduser /tmp/go*

        # Install NVM for Node.js version management
        source /usr/share/nvm/init-nvm.sh

        # Set Node.js memory limits to prevent heap out of memory
        export NODE_OPTIONS="--max-old-space-size=3072"

        # Stay in the arch packaging directory
        cd /work

        # give everyone write perms for /work
        chown -R builduser:builduser /work

        echo ""
        echo "=== Environment Ready ==="
        echo "Current directory: $(pwd)"
        echo "Files available:"
        ls -la
        echo ""
        echo "Quick tests you can run:"
        echo "  bash -n PKGBUILD                    # Check syntax"
        echo "  su builduser -c \"makepkg -sr --noconfirm\"  # Build package (will clone git repo)"
        echo "  systemd-analyze verify *.service    # Check services"
        echo "  bash -n environment.example         # Check config"
        echo ""
        echo "To switch to builduser: su builduser"
        echo "To build package: su builduser -c \"makepkg -sr --noconfirm\""
        echo ""
        echo "Starting root shell (use su builduser for package building)..."
        echo ""

        bash
    '
