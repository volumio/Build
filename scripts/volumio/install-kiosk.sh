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
  # Browser
  # TODO: Why not firefox? it seems to work OTB on most devices with less hassle?
  "chromium" "chromium-l10n"
  # Fonts
  "fonts-arphic-ukai" "fonts-arphic-gbsn00lp" "fonts-unfonts-core"
)

log "Installing ${#CMP_PACKAGES[@]} ${CMP_NAME} packages:" "" "${CMP_PACKAGES[*]}"
apt-get install -y "${CMP_PACKAGES[@]}" --no-install-recommends

log "${CMP_NAME} Dependencies installed!"

log "Creating ${CMP_NAME} dirs and scripts"
mkdir /data/volumiokiosk

#TODO: Document these!
# A lot of these flags are wrong/deprecated/not required
# eg. https://chromium.googlesource.com/chromium/src/+/4baa4206fac22a91b3c76a429143fc061017f318
# Translate: remove --disable-translate flag

CHROMIUM_FLAGS=(
  "--kiosk"
  "--touch-events"
  "--disable-touch-drag-drop"
  "--disable-overlay-scrollbar"
  "--enable-touchview"
  "--enable-pinch"
  "--window-position=0,0"
  "--disable-session-crashed-bubble"
  "--disable-infobars"
  "--disable-sync"
  "--no-first-run"
  "--no-sandbox"
  "--user-data-dir='/data/volumiokiosk'"
  "--disable-translate"
  "--show-component-extension-options"
  "--disable-background-networking"
  "--enable-remote-extensions"
  "--enable-native-gpu-memory-buffers"
  "--disable-quic"
  "--enable-fast-unload"
  "--enable-tcp-fast-open"
)

if [[ ${BUILD:0:3} != 'arm' ]]; then
  log "Adding additional chromium flags for x86"
  # Again, these flags probably need to be revisited and checked!
  CHROMIUM_FLAGS+=(
    #GPU
    "--ignore-gpu-blacklist"
    "--use-gl=desktop"
    "--disable-gpu-compositing"
    "--force-gpu-rasterization"
    "--enable-zero-copy"
  )
fi

log "Adding ${#CHROMIUM_FLAGS[@]} Chromium flags"
#TODO: Instead of all this careful escaping, make a simple template and add in CHROMIUM_FLAGS?
cat <<-EOF >/opt/volumiokiosk.sh
#!/usr/bin/env bash
#set -eo pipefail
exec >/var/log/volumiokiosk.log 2>&1

echo "Starting Kiosk"
start=\$(date +%s)

export DISPLAY=:0
# in case we want to cap hires monitors (e.g. 4K) to HD (1920x1080)
#CAPPEDRES="1920x1080"
#SUPPORTEDRES="$(xrandr | grep $CAPPEDRES)"
#if [ -z "$SUPPORTEDRES" ]; then
#  echo "Resolution $CAPPEDRES not found, skipping"
#else
#  echo "Capping resolution to $CAPPEDRES"
#  xrandr -s "$CAPPEDRES"
#fi

#TODO xpdyinfo does not work on a fresh install (freezes), skipping it just now
#Perhaps xrandr can be parsed instead? (Needs DISPLAY:=0 to be exported first)
#res=\$(xdpyinfo | awk '/dimensions:/ { print \$2; exit }')
#res=\${res/x/,}
#echo "Current probed resolution: \${res}"

xset -dpms
xset s off
[[ -e /data/volumiokiosk/Default/Preferences ]] && {
  sed -i 's/"exited_cleanly":false/"exited_cleanly":true/' /data/volumiokiosk/Default/Preferences
  sed -i 's/"exit_type":"Crashed"/"exit_type":"None"/' /data/volumiokiosk/Default/Preferences
}

if [ -L /data/volumiokiosk/SingletonCookie ]; then
  rm -rf /data/volumiokiosk/Singleton*
fi

# Wait for Volumio webUI to be available
while true; do timeout 3 bash -c "</dev/tcp/127.0.0.1/3000" >/dev/null 2>&1 && break; done
echo "Waited \$((\$(date +%s) - start)) sec for Volumio UI"

openbox-session &
  /usr/bin/chromium \\
	$(printf '    %s \\\n' "${CHROMIUM_FLAGS[@]}")
    http://localhost:3000
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
ExecStart=/usr/bin/startx /etc/X11/Xsession /opt/volumiokiosk.sh -- -keeptty
[Install]
WantedBy=multi-user.target
EOF

log "Enabling ${CMP_NAME} service"
ln -s /lib/systemd/system/volumio-kiosk.service /etc/systemd/system/multi-user.target.wants/volumio-kiosk.service

log "Setting localhost"
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
  #shellcheck disable=SC2094
  cat <<<"$(jq '.hdmi_enabled={value:true, type:"boolean"}' ${config_path})" >${config_path}
fi
