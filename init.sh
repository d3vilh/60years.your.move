#!/bin/bash
# Philipp 2026

set -e

DEFAULT_USER="philipp"
DEFAULT_VIDEO="/home/philipp/Videos/myvideo.mp4"

ask_yes_no() {
    local prompt="$1"
    read -rp "$prompt [Yes/no]: " answer

    case "${answer,,}" in
        n|no)
            return 1
            ;;
        *)
            return 0
            ;;
    esac
}

echo
read -rp "Enter Linux user [${DEFAULT_USER}]: " VIDEO_USER
VIDEO_USER=${VIDEO_USER:-$DEFAULT_USER}

echo
read -rp "Enter full path to video file [${DEFAULT_VIDEO}]: " VIDEO_FILE
VIDEO_FILE=${VIDEO_FILE:-$DEFAULT_VIDEO}

echo
echo "========== CONFIG =========="
echo "User       : ${VIDEO_USER}"
echo "Video file : ${VIDEO_FILE}"
echo "============================"
echo

if ask_yes_no "Proceed with removing X11/Desktop packages?"; then
    echo "[INFO] Removing X11/Desktop packages..."
    apt remove --purge -y xserver-xorg xinit openbox lightdm 2>/dev/null || true
    apt autoremove -y
fi

if ask_yes_no "Proceed with installing mpv?"; then
    echo "[INFO] Installing mpv..."
    apt update
    apt install -y mpv
fi

if ask_yes_no "Proceed with disabling graphical services?"; then
    echo "[INFO] Disabling graphical services..."

    systemctl stop lightdm 2>/dev/null || true
    systemctl stop display-manager 2>/dev/null || true

    systemctl set-default multi-user.target

    systemctl disable lightdm 2>/dev/null || true
    systemctl disable gdm 2>/dev/null || true
    systemctl disable gdm3 2>/dev/null || true
    systemctl disable sddm 2>/dev/null || true
    systemctl disable display-manager 2>/dev/null || true
fi

if ask_yes_no "Proceed with adding user to video group?"; then
    echo "[INFO] Adding ${VIDEO_USER} to video group..."
    usermod -aG video "${VIDEO_USER}"
fi

if ask_yes_no "Proceed with creating video-kiosk service?"; then
    echo "[INFO] Creating systemd service..."

    cat > /etc/systemd/system/video-kiosk.service <<EOF
[Unit]
Description=Fullscreen Video Player
After=multi-user.target

[Service]
User=${VIDEO_USER}
Group=video

StandardInput=tty
StandardOutput=tty
TTYPath=/dev/tty1
TTYReset=yes
TTYVHangup=yes
TTYVTDisallocate=yes

ExecStart=/bin/sh -c 'while true; do /usr/bin/mpv --fs --loop --keep-open=yes --vo=gpu --gpu-context=drm --hwdec=auto --no-osd-bar --really-quiet ${VIDEO_FILE}; sleep 1; done'

Restart=always
RestartSec=2

[Install]
WantedBy=multi-user.target
EOF
fi

if ask_yes_no "Proceed with enabling and starting video-kiosk service?"; then
    echo "[INFO] Enabling service..."

    systemctl daemon-reload
    systemctl enable video-kiosk.service
    systemctl restart video-kiosk.service
fi

echo
echo "[OK] Installation completed."
echo
echo "Useful commands:"
echo "systemctl status video-kiosk.service"
echo "journalctl -u video-kiosk.service -f"