#!/usr/bin/env bash
set -eo pipefail

CMP_NAME=$(basename "$(dirname "${BASH_SOURCE[0]}")")
CMP_NAME=volumio-kiosk
log "Installing $CMP_NAME" "ext"

#shellcheck source=/dev/null
source /etc/os-release
export DEBIAN_FRONTEND=noninteractive

CMP_PACKAGES=(
  # Keyboard config
  "keyboard-configuration"
  # Display stuff
  "openbox" "unclutter" "xorg" "xinit"
  #TODO: Figure out new x configuration later, for now legacy FTW
  "xserver-xorg-legacy"
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
while true; do timeout 3 bash -c \"</dev/tcp/127.0.0.1/3000\" >/dev/null 2>&1 && break; done
sed -i 's/\"exited_cleanly\":false/\"exited_cleanly\":true/' /data/volumiokiosk/Default/Preferences
sed -i 's/\"exit_type\":\"Crashed\"/\"exit_type\":\"None\"/' /data/volumiokiosk/Default/Preferences
xset -dpms
xset s off
openbox-session &
while true; do
  /usr/bin/chromium-browser \\
    --simulate-outdated-no-au='Tue, 31 Dec 2099 23:59:59 GMT' \\
    --disable-pinch \\
    --kiosk \\
    --no-first-run \\
    --noerrdialogs \\
    --disable-3d-apis \\
    --disable-breakpad \\
    --disable-crash-reporter \\
    --disable-infobars \\
    --disable-session-crashed-bubble \\
    --disable-translate \\
    --user-data-dir='/data/volumiokiosk' \
    http://localhost:3000
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
User=root
Group=root
ExecStart=/usr/bin/startx /etc/X11/Xsession /opt/volumiokiosk.sh
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
echo "Setting localhost"
echo '{"localhost": "http://127.0.0.1:3000"}' >/volumio/http/www/app/local-config.json
if [ -d "/volumio/http/www3" ]; then
  echo '{"localhost": "http://127.0.0.1:3000"}' >/volumio/http/www3/app/local-config.json
fi

if [[ ${VOLUMIO_HARDWARE} != motivo ]]; then

  log "Enabling UI for HDMI output selection"
  echo '[{"value": false,"id":"section_hdmi_settings","attribute_name": "hidden"}]' >/volumio/app/plugins/system_controller/system/override.json

  log "Setting HDMI UI enabled by default"
  config_path="/volumio/app/plugins/system_controller/system/config.json"
  # Should be okay right?
  cat <<<"$(jq '.hdmi_enabled={value:true, type:"boolean"}' ${config_path})" >${config_path}
fi
