#!/bin/bash
# Philipp 2026

set -e

DEFAULT_USER="philipp"
DEFAULT_VIDEO_DIR="/home/philipp/Videos"
DEFAULT_VIDEO_FILE="/home/philipp/Videos/myvideo2.mp4"
DEFAULT_GIT_REPO="https://github.com/d3vilh/60years.your.move.git"
DEFAULT_GIT_VIDEO_PATH="video/myvideo2.mp4"

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
read -rp "Enter video directory [${DEFAULT_VIDEO_DIR}]: " VIDEO_DIR
VIDEO_DIR=${VIDEO_DIR:-$DEFAULT_VIDEO_DIR}

echo
read -rp "Enter final full path to video file [${DEFAULT_VIDEO_FILE}]: " VIDEO_FILE
VIDEO_FILE=${VIDEO_FILE:-$DEFAULT_VIDEO_FILE}

echo
read -rp "Enter Git repository URL [${DEFAULT_GIT_REPO}]: " GIT_REPO
GIT_REPO=${GIT_REPO:-$DEFAULT_GIT_REPO}

echo
read -rp "Enter video path inside repository [${DEFAULT_GIT_VIDEO_PATH}]: " GIT_VIDEO_PATH
GIT_VIDEO_PATH=${GIT_VIDEO_PATH:-$DEFAULT_GIT_VIDEO_PATH}

echo
echo "========== CONFIG =========="
echo "User               : ${VIDEO_USER}"
echo "Video dir          : ${VIDEO_DIR}"
echo "Final video file   : ${VIDEO_FILE}"
echo "Git repository     : ${GIT_REPO}"
echo "Video inside repo  : ${GIT_VIDEO_PATH}"
echo "============================"
echo

if ask_yes_no "Proceed with creating video directory?"; then
    echo "[INFO] Creating video directory..."

    mkdir -p "${VIDEO_DIR}"

    chown -R "${VIDEO_USER}:${VIDEO_USER}" "${VIDEO_DIR}"
fi

if ask_yes_no "Proceed with downloading video from GitHub LFS repository?"; then
    echo "[INFO] Installing git and git-lfs..."

    apt update
    apt install -y git git-lfs

    echo "[INFO] Initializing git-lfs..."

    git lfs install

    echo "[INFO] Removing old temporary repository..."

    rm -rf /tmp/video-repo

    echo "[INFO] Cloning repository..."

    git clone "${GIT_REPO}" /tmp/video-repo

    cd /tmp/video-repo

    echo "[INFO] Downloading LFS objects..."

    git lfs pull

    echo "[INFO] Copying video file..."

    cp "${GIT_VIDEO_PATH}" "${VIDEO_FILE}"

    chown "${VIDEO_USER}:${VIDEO_USER}" "${VIDEO_FILE}"

    chmod 600 "${VIDEO_FILE}"

    echo "[INFO] Video downloaded successfully."
fi

if ask_yes_no "Proceed with removing X11/Desktop packages?"; then
    echo "[INFO] Removing X11/Desktop packages..."

    apt remove --purge -y \
        xserver-xorg \
        xinit \
        openbox \
        lightdm 2>/dev/null || true

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
Environment=HOME=/home/philipp
WorkingDirectory=/home/philipp

StandardInput=tty
StandardOutput=journal
StandardError=journal
TTYVHangup=no
TTYVTDisallocate=no
TTYPath=/dev/tty1
TTYReset=yes

#ExecStart=/bin/sh -c 'while true; do /usr/bin/mpv --fullscreen --no-audio --hwdec=no --profile=sw-fast --vo=gpu --gpu-context=drm --framedrop=vo --no-osd-bar --really-quiet /home/philipp/Videos/myvideo.mp4; sleep 1; done'
ExecStart=/usr/bin/mpv --fullscreen --loop=inf --no-audio --hwdec=no --profile=sw-fast --vo=gpu --gpu-context=drm --framedrop=vo --no-osd-bar --really-quiet ${VIDEO_FILE}

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
