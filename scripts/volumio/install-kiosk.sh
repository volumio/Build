#!/bin/bash
export DEBIAN_FRONTEND=noninteractive

log "Installing Kiosk" "info"
kiosk_pkgs="keyboard-configuration xinit xorg openbox libexif12 unclutter"
# Browser of choice
kiosk_pkgs+=" midori"

apt-get install -y $kiosk_pkgs --no-install-recommends
log "Kiosk dependencies installed" "okay"
log "Creating Kiosk start script"
cat<<-EOF>/opt/volumiokiosk.sh
#!/bin/bash
mkdir -p /data/volumiokiosk
export DISPLAY=:0
xset s off -dpms
export XDG_CACHE_HOME=/data/volumiokiosk
rm -rf /data/volumiokiosk/Singleton*
openbox-session &
sleep 4
while true; do
  midori -a http://localhost:3000 -e Fullscreen
done
EOF
chmod +x /opt/volumiokiosk.sh

log "Creating Systemd Unit for Kiosk"
cat<<-EOF>/lib/systemd/system/volumio-kiosk.service
[Unit]
Description=Start Volumio Kiosk
Wants=volumio.service
After=volumio.service
[Service]
Type=simple
User=root
Group=root
ExecStart=/usr/bin/startx /etc/X11/Xsession /opt/volumiokiosk.sh
# Give a reasonable amount of time for the server to start up/shut down
TimeoutSec=300
[Install]
WantedBy=multi-user.target
EOF

log "Enabling kiosk"
ln -s /lib/systemd/system/volumio-kiosk.service /etc/systemd/system/multi-user.target.wants/volumio-kiosk.service

log "  Allowing volumio to start an Xsession"
sed -i "s/allowed_users=console/allowed_users=anybody/" /etc/X11/Xwrapper.config

log "Hide Mouse cursor"

cat<<-EOF>/root/.xinitrc
#!/bin/sh
if [ -d /etc/X11/xinit/xinitrc.d ]; then
  for f in /etc/X11/xinit/xinitrc.d/*; do
    [ -x "$f" ] && . "$f"
  done
  unset f
fi
xrdb -merge ~/.Xresources
xsetroot -cursor_name left_ptr &
exec openbox-session
exec unclutter &
EOF


log "Enabling UI for HDMI output selection"
echo '[{"value": false,"id":"section_hdmi_settings","attribute_name": "hidden"}]' > /volumio/app/plugins/system_controller/system/override.json

log "Setting HDMI UI enabled by default"
config_path="/volumio/app/plugins/system_controller/system/config.json"
cat <<< $"(jq '.hdmi_enabled={value:true, type:\"boolean\"}' ${config_path})" > ${config_path}
