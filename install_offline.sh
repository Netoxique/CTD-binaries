#!/usr/bin/env bash
# install_ctd.sh  –  installer for CTD
set -euo pipefail

OWNER=ErnestoReza
BINREPO=CTD-binaries
BASENAME=Magno
INSTALL_DIR=/opt/ctd
SERVICE=ctd.service

run_install_scripts() {
  local scripts_dir="$INSTALL_DIR/LCD.dist/Install"
  local marker_path="$INSTALL_DIR/LCD.dist/.install_scripts_complete"
  local script script_name rc started_at elapsed

  # A previous release's marker must not hide an incomplete installation retry.
  rm -f "$marker_path"

  if [[ ! -d "$scripts_dir" ]]; then
    echo " ! No install scripts directory found at $scripts_dir"
    return 0
  fi

  shopt -s nullglob
  local scripts=("$scripts_dir"/*.sh)
  shopt -u nullglob

  if (( ${#scripts[@]} == 0 )); then
    echo " ! No install scripts found in $scripts_dir"
    return 0
  fi

  echo "=== Running install scripts ..."
  for script in "${scripts[@]}"; do
    script_name="$(basename "$script")"
    echo "=== Running $script_name ..."

    started_at=$SECONDS
    rc=0
    bash "$script" || rc=$?
    elapsed=$((SECONDS - started_at))
    echo "Finished $script_name in ${elapsed}s (exit $rc)."

    if [[ "$rc" -eq 0 ]]; then
      continue
    fi

    if [[ "$script_name" == "service_check.sh" && "$rc" -eq 10 ]]; then
      echo "CTD service updated."
      continue
    fi

    echo "Install script failed: $script_name exited with $rc" >&2
    return "$rc"
  done

  touch "$marker_path"
}

if [[ $EUID -ne 0 ]]; then
  echo " !! Please run as root: sudo bash $0"
  exit 1
fi

echo " ! Detecting OS release …"
RELEASE=$(lsb_release -cs)      # buster | bullseye | bookworm | etc.
ASSET="${BASENAME}-${RELEASE}.tar.gz"
URL="https://github.com/${OWNER}/${BINREPO}/releases/latest/download/${ASSET}"

echo " ! Installing into $INSTALL_DIR"
mkdir -p "$INSTALL_DIR"
cd      "$INSTALL_DIR"

echo "=== Unpacking ..."
tar -xzf "/home/pi/Desktop/CTD/${ASSET}"                      # produces $BASENAME.dist/

BIN_PATH="$INSTALL_DIR/LCD.dist/LCD.bin"
ln -sf "$BIN_PATH" /usr/local/bin/ctd
chmod +x   /usr/local/bin/ctd

/bin/cat > "/etc/logrotate.d/ctd" <<EOF
/var/log/ctd.log {
    daily
    rotate 14
    missingok
    notifempty
    copytruncate
}
EOF

echo "=== Removing old CTD installation and backing up ..."

mkdir -p "/home/pi/Desktop/temp/lib"

if [[ -d "/home/pi/Desktop/CTD/lib/test_files" ]]; then
  cp -a "/home/pi/Desktop/CTD/lib/test_files/." "/home/pi/Desktop/temp/lib/test_files"
else
  echo " ! No test_files directory to back up."
fi

if [[ -f "/home/pi/Desktop/CTD/lib/config.ini" ]]; then
  cp "/home/pi/Desktop/CTD/lib/config.ini" "/home/pi/Desktop/temp/lib/config.ini"
else
  echo " ! No config.ini file to back up."
fi

if [[ -f "/home/pi/Desktop/CTD/event_reporting.json" ]]; then
  cp "/home/pi/Desktop/CTD/event_reporting.json" "/home/pi/Desktop/temp/event_reporting.json"
fi

rm -rf "/home/pi/Desktop/CTD"

echo "=== Creating directories ..."
mkdir -p "/home/pi/Desktop/CTD"
cp -a "$INSTALL_DIR/LCD.dist/lib/." "/home/pi/Desktop/CTD/lib"
cp "$INSTALL_DIR/LCD.dist/VERSION" "/home/pi/Desktop/CTD/VERSION"
#cp -a "$INSTALL_DIR/LCD.dist/Resources/." "/home/pi/Desktop/CTD/Resources"
#cp -a "$INSTALL_DIR/LCD.dist/Verry Important Files/." "/home/pi/Desktop/CTD/Verry Important Files"
if [[ -d "/home/pi/Desktop/temp/lib/test_files" ]]; then
  cp -a "/home/pi/Desktop/temp/lib/test_files/." "/home/pi/Desktop/CTD/lib/test_files"
fi

if [[ -f "/home/pi/Desktop/temp/lib/config.ini" ]]; then
  cp "/home/pi/Desktop/temp/lib/config.ini" "/home/pi/Desktop/CTD/lib/config.ini"
fi

if [[ -f "/home/pi/Desktop/temp/event_reporting.json" ]]; then
  cp "/home/pi/Desktop/temp/event_reporting.json" "/home/pi/Desktop/CTD/event_reporting.json"
fi

rm -rf "/home/pi/Desktop/temp"

chown -R pi:pi "/home/pi/Desktop/CTD"

echo "=== Configuring /etc/rc.local ..."
RC_LOCAL="/etc/rc.local"
/bin/cat > "$RC_LOCAL" <<EOF
#!/bin/sh -e
#
# rc.local
#
# This script is executed at the end of each multiuser runlevel.
# Make sure that the script will "exit 0" on success or any other
# value on error.
#
# In order to enable or disable this script just change the execution
# bits.
#
# By default this script does nothing.

exit 0
EOF

echo "=== Deleting Backups ..."
rm -rf /home/pi/Documents/*

echo "=== Running installation scripts ..."
run_install_scripts

echo "=== Installation complete. Logs:"
systemctl --no-pager status "$SERVICE" ||
  echo "CTD is enabled and will start after the installation reboot."
echo "Use   journalctl -u $SERVICE -f   to follow output."

reboot
