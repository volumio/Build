#!/bin/sh
export DEBIAN_FRONTEND=noninteractive

echo "Fixing keyboard input issue"
apt-get update
apt-get install -y keyboard-configuration --no-install-recommends

echo "Installing Display Plugin dependencies"

echo "Installing Graphical environment"
sudo apt-get install -y xinit xorg openbox libexif12 unclutter --no-install-recommends

echo "Temporarily adding Backports sources"
echo "deb http://ftp.de.debian.org/debian jessie-backports main" > /etc/apt/sources.list.d/jessie-backports.list

echo "Installing Midori"
apt-get update
apt-get install -y midori --no-install-recommends

echo "Removing temporary Backgports sources"
rm /etc/apt/sources.list.d/jessie-backports.list

echo "Cleaning"
rm -f /var/lib/apt/lists/*archive*
apt-get clean

echo "Dependencies installed"

echo "Creating Kiosk start script"
echo "#!/bin/bash
mkdir -p /data/volumiokiosk
export DISPLAY=:0
xset s off -dpms
export XDG_CACHE_HOME=/data/volumiokiosk
rm -rf /data/volumiokiosk/Singleton*
openbox-session &
sleep 4
while true; do
  midori -a http://localhost:3000 -e Fullscreen
done" > /opt/volumiokiosk.sh
/bin/chmod +x /opt/volumiokiosk.sh

echo "Creating Systemd Unit for Kiosk"
echo "[Unit]
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
" > /lib/systemd/system/volumio-kiosk.service

echo "Enabling kiosk"
/bin/ln -s /lib/systemd/system/volumio-kiosk.service /etc/systemd/system/multi-user.target.wants/volumio-kiosk.service

echo "  Allowing volumio to start an xsession"
/bin/sed -i "s/allowed_users=console/allowed_users=anybody/" /etc/X11/Xwrapper.config

echo "Hide Mouse cursor"

echo "#!/bin/sh
if [ -d /etc/X11/xinit/xinitrc.d ]; then
  for f in /etc/X11/xinit/xinitrc.d/*; do
    [ -x "$f" ] && . "$f"
  done
  unset f
fi
xrdb -merge ~/.Xresources         
xsetroot -cursor_name left_ptr &  
exec openbox-session              
exec unclutter &" > /root/.xinitrc

echo "Enabling UI for HDMI output selection"
echo '[{"value": false,"id":"section_hdmi_settings","attribute_name": "hidden"}]' > /volumio/app/plugins/system_controller/system/override.json

echo "Setting HDMI UI enabled by default"
/usr/bin/jq '.hdmi_enabled.value = true' /volumio/app/plugins/system_controller/system/config.json > /hdmi && mv /hdmi /volumio/app/plugins/system_controller/system/config.json
/usr/bin/jq '.hdmi_enabled.type = "boolean"' /volumio/app/plugins/system_controller/system/config.json > /hdmi && mv /hdmi /volumio/app/plugins/system_controller/system/config.json


