# menhera.sh

Start a RAM Linux system (Debian for now) without requiring physical access to your server.

With menhera.sh you can:
  * format your system disk or create RAID
  * install a new distro
  * do important maintenance or backup with nobody writing to your root filesystem
  * ...

with only SSH!

"menhera" is short for "mental healer". 

## WARNING

> I am not responsible for bricked devices, dead HDDs and SSDs, unreplied tickets, thermonuclear war, or you getting fired because your device is hacked to mine bitcoin. Please do some research if you have any concerns about this script before using it! YOU are choosing to run this script, and if you point the finger at me for messing up your device, I will laugh at you.

## Dependencies

  * Linux kernel: overlayfs and tmpfs support
  * systemd
  * squashfs-tools
  * curl

## Usage

Just download and run.

## Known issues

  * Cannot auto detect rootfs URL

## Thanks

  * This project is inspired by [marcan/takeover.sh](https://github.com/marcan/takeover.sh)
  * The major code came from [a maintenance writeup on my blog](https://blog.swineson.me/debian-9-csm-online-convert-root-partition-to-raid/) (in Simp. Chinese)
  * [xTom.com](https://xtom.com/) donated a VPS for my testing