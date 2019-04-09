# menhera.sh

Start a RAM Linux system (Debian for now) without requiring physical access to your server.

With menhera.sh you can:
  * format your system disk or create RAID
  * install a new distro
  * do important maintenance or backup with nobody writing to your root filesystem
  * ...

with only SSH!

"menhera" is short for "mental healer". 

## Dependencies

  * Linux kernel: overlayfs and tmpfs support
  * systemd
  * squashfs-tools
  * wget

## Usage

Just download and run.

## Known issues

  * Cannot auto detect rootfs URL

## Thanks

  * This project is inspired by [marcan/takeover.sh](https://github.com/marcan/takeover.sh)
  * The major code came from [a maintenance writeup on my blog](https://blog.swineson.me/debian-9-csm-online-convert-root-partition-to-raid/) (in Simp. Chinese)
  * [xTom.com](https://xtom.com/) donated a VPS for my testing