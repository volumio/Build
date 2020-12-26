#!/usr/bin/env bash
## Kioskmode setup for x86 devices
#TODO: Combine this with regular kiosk scripts?
CMP_NAME=volumio-kiosk-x86

#shellcheck source=/dev/null
source /etc/os-release
export DEBIAN_FRONTEND=noninteractive

CMP_PACKAGES=(
  # Keyboard config
  "keyboard-configuration"
  # Display stuff
  "openbox" "unclutter" "xorg" "xinit"
  # Browser # TODO: Why not firefox?
  "chromium" "chromium-l10n"
  # Fonts
  "fonts-arphic-ukai" "fonts-arphic-gbsn00lp" "fonts-unfonts-core"
)

log "Installing ${#CMP_PACKAGES[@]} ${CMP_NAME} packages:" "" "${CMP_PACKAGES[@]}"
apt-get install -y "${CMP_PACKAGES[@]}" --no-install-recommends

log "${CMP_NAME} Dependencies installed!"

log "Creating ${CMP_NAME} dirs and scripts"
mkdir /data/volumiokiosk

cat <<-EOF >/opt/volumiokiosk.sh
#!/usr/bin/env bash
set -eo pipefail
exec >"/var/log/volumiokiosk.log" 2>&1
# Wait for Volumio webUI to be available 
while true; do timeout 3 bash -c "</dev/tcp/127.0.0.1/3000" >/dev/null 2>&1 && break; done
export DISPLAY=:0
xset -dpms
xset s off
[[ -e /data/volumiokiosk/Default/Preferences ]] && {
  sed -i 's/"exited_cleanly":false/"exited_cleanly":true/' /data/volumiokiosk/Default/Preferences
  sed -i 's/"exit_type":"Crashed"/"exit_type":"None"/' /data/volumiokiosk/Default/Preferences
}
openbox-session &
while true; do
  # TODO: Why not just launch a private window?
  rm -rf ~/.{config,cache}/chromium/ || echo "No {config,cache} folders to remove"
  /usr/bin/chromium \
    --kiosk \
    --touch-events \
    --disable-touch-drag-drop \
    --disable-overlay-scrollbar \
    --enable-touchview \
    --enable-pinch \
    --window-size=800,480 \
    --window-position=0,0 \
    --disable-session-crashed-bubble \
    --disable-infobars \
    --no-first-run \
    --no-sandbox \
    --user-data-dir='/data/volumiokiosk' \
    --disable-translate \
    --show-component-extension-options \
    --ignore-gpu-blacklist \
    --disable-background-networking \
    --use-gl=egl \
    --enable-remote-extensions \
    --enable-native-gpu-memory-buffers \
    --disable-quic \
    --enable-fast-unload \
    --enable-tcp-fast-open \
    --disable-gpu-compositing \
    --force-gpu-rasterization \
    --enable-zero-copy \
    'http://localhost:3000'
done
EOF
chmod +x /opt/volumiokiosk.sh

log "Creating Systemd Unit for ${CMP_NAME}"
#TODO: Kiosk should be launched by a Kiosk user and not by root!?
#usermod -aG tty,video kiosk
cat <<-EOF >/lib/systemd/system/volumio-kiosk.service
[Unit]
Description=Start Volumio Kiosk
Wants=volumio.service
After=volumio.service
[Service]
Type=simple
User=root
Group=root
ExecStart=/usr/bin/startx /etc/X11/Xsession /opt/volumiokiosk.sh -- -keeptty
[Install]
WantedBy=multi-user.target
EOF

log "Enabling ${CMP_NAME} service"
ln -s /lib/systemd/system/volumio-kiosk.service /etc/systemd/system/multi-user.target.wants/volumio-kiosk.service
