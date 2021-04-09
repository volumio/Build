#!/bin/sh
HARDWARE=$(cat /etc/os-release | grep HARDWARE | tr -d 'VOLUMIO_HARDWARE="')

echo "Installing Volumio local UI"

export DEBIAN_FRONTEND=noninteractive

echo "Fixing keyboard input issue"
apt-get update
apt-get install -y keyboard-configuration --no-install-recommends

echo "Installing Vivaldi Dependencies"
sudo apt-get update
sudo apt-get -y install

echo "Installing Graphical environment"
sudo apt-get install -y xinit xorg openbox libexif12 unclutter --no-install-recommends

echo "Download Vivaldi"
cd /home/volumio/
wget https://repo.volumio.org/Volumio2/Vivaldi/vivaldi-stable_2.7.1628.33-1_armhf.deb

echo "Install  Vivaldi"
sudo dpkg -i /home/volumio/vivaldi-*.deb
sudo apt-get install -y -f --no-install-recommends
sudo dpkg -i /home/volumio/vivaldi-*.deb

rm /home/volumio/vivaldi-*.deb

echo "Cleaning Vivaldi Apt Sources"
rm /etc/apt/sources.list.d/vivaldi.list

echo "Installing Japanese, Korean, Chinese and Taiwanese fonts"
apt-get -y install fonts-arphic-ukai fonts-arphic-gbsn00lp fonts-unfonts-core

echo "Dependencies installed"

echo "Creating Kiosk Data dir"
mkdir /data/volumiokiosk

echo " Creating Vivaldi kiosk start script" 

echo "#!/bin/bash 

mkdir -p /data/volumiokiosk 
export DISPLAY=:0 

xset s off -dpms 
rm -rf /data/volumiokiosk/Singleton* 

sed -i 's/"exited_cleanly":false/"exited_cleanly":true/' /data/volumiokiosk/Default/Preferences 
sed -i 's/"exit_type":"Crashed"/"exit_type":"None"/' /data/volumiokiosk/Default/Preferences 

openbox-session & 
sleep 4 

/usr/bin/vivaldi --kiosk --no-sandbox --disable-background-networking --disable-remote-extensions --disable-pinch --ignore-gpu-blacklist --use-gl=egl --disable-gpu-compositing --enable-gpu-rasterization --enable-zero-copy --disable-smooth-scrolling --enable-scroll-prediction --max-tiles-for-interest-area=512 --num-raster-threads=4 --enable-low-res-tiling --user-agent="volumiokiosk-memorysave-touch" --touch-events --user-data-dir='/data/volumiokiosk' --force-device-scale-factor=1.2 --app=http://localhost:3000 " > /opt/volumiokiosk.sh 

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

if  [ "$HARDWARE" != "motivo" ]; then

  echo "Enabling UI for HDMI output selection"
  echo '[{"value": false,"id":"section_hdmi_settings","attribute_name": "hidden"}]' > /volumio/app/plugins/system_controller/system/override.json

  echo "Setting HDMI UI enabled by default"
  /usr/bin/jq '.hdmi_enabled.value = true' /volumio/app/plugins/system_controller/system/config.json > /hdmi && mv /hdmi /volumio/app/plugins/system_controller/system/config.json
  /usr/bin/jq '.hdmi_enabled.type = "boolean"' /volumio/app/plugins/system_controller/system/config.json > /hdmi && mv /hdmi /volumio/app/plugins/system_controller/system/config.json
fi

echo "Setting localhost"
echo '{"localhost": "http://127.0.0.1:3000"}' > /volumio/http/www/app/local-config.json
if [ -d "/volumio/http/www3" ]; then
  echo '{"localhost": "http://127.0.0.1:3000"}' > /volumio/http/www3/app/local-config.json
fi
