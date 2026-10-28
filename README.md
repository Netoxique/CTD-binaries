# CTD-binaries

Built CTD release packages and installation entry points. The CTD source
repository is the source of truth for both installers: copy `install_online.sh`
and `install_offline.sh` here whenever they change, and keep Unix (LF) line endings.

## Installation

Run installers on the Raspberry Pi as root. Both installers reboot the unit
after a successful installation.

- **Online (Trixie):** run `sudo bash install_online.sh`. It downloads
  `Magno-<OS codename>.tar.gz` from this repository's latest GitHub release.
  Buster runs offline and is rejected before downloading.
- **Offline (Buster or Trixie):** place the matching release archive at
  `/home/pi/Desktop/CTD/Magno-<OS codename>.tar.gz`, then run
  `sudo bash install_offline.sh`. For example, use `Magno-trixie.tar.gz` on Trixie
  or `Magno-buster.tar.gz` on Buster. The archive location is fixed; it is not
  resolved relative to the script.

## Client updates

Existing clients use `update_online.sh` or `update_offline.sh` from their installed
release package. Those scripts are maintained and packaged by the CTD source
repository; copying these installers alone does not update existing clients.
