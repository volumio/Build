#!/usr/bin/env bash
# shellcheck disable=SC2034
## Kioskmode setup for x86 devices

CMP_NAME=volumio-kiosk-x86

#shellcheck source=/dev/null
source /etc/os-release
export DEBIAN_FRONTEND=noninteractive

CMP_PACKAGES=(
  # Keyboard config
  "keyboard-configuration"
  # Display stuff
  "openbox" "unclutter" "xorg" "xinit" "libexif12"
  # Browser
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
#set -eo pipefail
export DISPLAY=:0
xset -dpms
xset s off
sed -i 's/"exited_cleanly":false/"exited_cleanly":true/' /data/volumiokiosk/Default/Preferences
sed -i 's/"exit_type":"Crashed"/"exit_type":"None"/' /data/volumiokiosk/Default/Preferences
openbox-session &
while true; do
  rm -rf ~/.{config,cache}/chromium/
  /usr/bin/chromium \\
		--kiosk \\
		--touch-events \\
		--disable-touch-drag-drop \\
		--disable-overlay-scrollbar \\
		--enable-touchview \\
		--enable-pinch \\
		--window-size=800,480 \\
		--window-position=0,0 \\
		--disable-session-crashed-bubble \\
		--disable-infobars \\
		--no-first-run \\
		--no-sandbox \\
		--user-data-dir='/data/volumiokiosk' \\
		--disable-translate \\
		--show-component-extension-options \\
		--ignore-gpu-blacklist \\
		--disable-background-networking \\
		--use-gl=egl \\ 
		--enable-remote-extensions \\
		--enable-native-gpu-memory-buffers \\
		--disable-quic \\
		--enable-fast-unload \\
		--enable-tcp-fast-open \\
		--disable-gpu-compositing \\
		--force-gpu-rasterization \\
		--enable-zero-copy \\
		'http://localhost:3000'
done
EOF
chmod +x /opt/volumiokiosk.sh

log "Creating Systemd Unit for ${CMP_NAME}"
cat <<-EOF >/lib/systemd/system/volumio-kiosk.service
[Unit]
Description=Start Volumio Kiosk
Wants=volumio.service
After=volumio.service
[Service]
Type=simple
User=volumio
Group=audio
ExecStart=/usr/bin/startx /etc/X11/Xsession /opt/volumiokiosk.sh 
# Give a reasonable amount of time for the server to start up/shut down
TimeoutSec=300
[Install]
WantedBy=multi-user.target
EOF

log "Enabling ${CMP_NAME} service"
ln -s /lib/systemd/system/volumio-kiosk.service /etc/systemd/system/multi-user.target.wants/volumio-kiosk.service

log "Allowing volumio to start an Xsession"
sed -i "s/allowed_users=console/allowed_users=anybody/" /etc/X11/Xwrapper.config

log "Hiding mouse cursor"
cat <<-'EOF' >/root/.xinitrc
#!/bin/sh

if [ -d /etc/X11/xinit/xinitrc.d ]; then
  for f in /etc/X11/xinit/xinitrc.d/*; do
    [ -x "$f" ] && . "$f"
  done
  unset f
fi

xrdb -merge ~/.Xresources         # aggiorna x resources db

#xscreensaver -no-splash &         # avvia il demone di xscreensaver
xsetroot -cursor_name left_ptr &  # setta il cursore di X
#sh ~/.fehbg &                     # setta lo sfondo con feh

exec openbox-session              # avvia il window manager

exec unclutter &
EOF


