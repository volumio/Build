#!/bin/sh

echo "Installing Volumio local UI"

export DEBIAN_FRONTEND=noninteractive

echo "Fixing keyboard input issue"
apt-get update
apt-get install -y keyboard-configuration --no-install-recommends

echo "Installing Chromium Dependencies"
sudo apt-get update
sudo apt-get -y install

echo "Installing Graphical environment"
sudo apt-get install -y xinit xorg openbox libexif12 unclutter --no-install-recommends

echo "Download Chromium"
cd /home/volumio/
wget http://launchpadlibrarian.net/234969703/chromium-browser_48.0.2564.82-0ubuntu0.15.04.1.1193_armhf.deb
wget http://launchpadlibrarian.net/234969705/chromium-codecs-ffmpeg-extra_48.0.2564.82-0ubuntu0.15.04.1.1193_armhf.deb

echo "Install  Chromium"
sudo dpkg -i /home/volumio/chromium-*.deb
sudo apt-get install -y -f
sudo dpkg -i /home/volumio/chromium-*.deb

rm /home/volumio/chromium-*.deb

echo "Installing Japanese, Korean, Chinese and Taiwanese fonts"
apt-get -y install fonts-arphic-ukai fonts-arphic-gbsn00lp fonts-unfonts-core

echo "Dependencies installed"

echo "Creating Kiosk Data dir"
mkdir /data/volumiokiosk

echo "  Creating chromium kiosk start script"
echo "#!/bin/bash
mkdir -p /data/volumiokiosk
export DISPLAY=:0
xset s off -dpms
rm -rf /data/volumiokiosk/Singleton*
sed -i 's/"exited_cleanly":false/"exited_cleanly":true/' /data/volumiokiosk/Default/Preferences
sed -i 's/"exit_type":"Crashed"/"exit_type":"None"/' /data/volumiokiosk/Default/Preferences
openbox-session &
sleep 4
  /usr/bin/chromium-browser --kiosk --touch-events --disable-touch-drag-drop --disable-overlay-scrollbar --enable-touchview --enable-pinch --window-size=800,480 --window-position=0,0 --disable-session-crashed-bubble --disable-infobars --no-first-run --no-sandbox --user-data-dir='/data/volumiokiosk' --disable-translate --show-component-extension-options --ignore-gpu-blacklist --disable-background-networking --use-gl=egl --enable-remote-extensions --enable-native-gpu-memory-buffers --disable-quic --enable-fast-unload --enable-tcp-fast-open --disable-gpu-compositing --force-gpu-rasterization --enable-zero-copy --app=http://localhost:3000
" > /opt/volumiokiosk.sh
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
ExecStart=/usr/bin/startx /etc/X11/Xsession /opt/volumiokiosk.sh -- -keeptty
# Give a reasonable amount of time for the server to start up/shut down
TimeoutSec=300
[Install]
WantedBy=multi-user.target
" > /lib/systemd/system/volumio-kiosk.service
/bin/ln -s /lib/systemd/system/volumio-kiosk.service /etc/systemd/system/multi-user.target.wants/volumio-kiosk.service

echo "  Allowing volumio to start an xsession"
/bin/sed -i "s/allowed_users=console/allowed_users=anybody/" /etc/X11/Xwrapper.config


echo "Enabling kiosk"
/bin/ln -s /lib/systemd/system/volumio-kiosk.service /etc/systemd/system/multi-user.target.wants/volumio-kiosk.service

echo "Enabling UI for HDMI output selection"
echo '[{"value": false,"id":"section_hdmi_settings","attribute_name": "hidden"}]' > /volumio/app/plugins/system_controller/system/override.json

echo "Setting HDMI UI enabled by default"
/usr/bin/jq '.hdmi_enabled.value = true' /volumio/app/plugins/system_controller/system/config.json > /hdmi && mv /hdmi /volumio/app/plugins/system_controller/system/config.json
/usr/bin/jq '.hdmi_enabled.type = "boolean"' /volumio/app/plugins/system_controller/system/config.json > /hdmi && mv /hdmi /volumio/app/plugins/system_controller/system/config.json

echo "Setting localhost"
echo '{"localhost": "http://127.0.0.1:3000"}' > /volumio/http/www/app/local-config.json
if [ -d "/volumio/http/www3" ]; then
  echo '{"localhost": "http://127.0.0.1:3000"}' > /volumio/http/www3/app/local-config.json
fi
