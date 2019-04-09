# menhera.sh

Start a RAM Linux system (Debian for now) without requiring physical access to your server.

With `menhera.sh` you can:
  * format your system disk or create RAID
  * install a new distro
  * do important maintenance or backup with nobody writing to your root filesystem
  * ...

with only SSH!

"menhera" is short for "mental healer". 

## WARNING

I am not responsible for bricked devices, dead HDDs and SSDs, unreplied tickets, thermonuclear war, or you getting fired because your device is hacked to mine bitcoin. Please do some research if you have any concerns about this script before using it! YOU are choosing to run this script, and if you point the finger at me for messing up your device, I will laugh at you.

## Dependencies

  * Linux kernel: overlayfs and tmpfs support
  * systemd
  * squashfs-tools
  * curl
  * ~400MiB RAM in theory

## Usage

  1. Save your work
  1. Backup all your important files
  1. Shutdown as many services and programs you can on the victim
  1. If you use SSH to connect to the server, make sure you can log in directly as root using SSH
  1. run the script, and follow the instructions

`menhera.sh` will try to download a new rootfs into the memory, replace the old rootfs and kill all processes reading the old rootfs. The old rootfs will be mounted to `/mnt/oldroot`. An example filesystem structure after running `menhera.sh` on my test VPS:

```
root@localhost:~# findmnt
TARGET                                SOURCE     FSTYPE     OPTIONS
/                                     overlay    overlay    rw,relatime,lowerdir=/tmp/menhera/newrootro,upperdir=/tmp/menhera/newrootrw,workdir=/tmp/menhera/overlayfs_workdir
├─/sys                                sysfs      sysfs      rw,nosuid,nodev,noexec,relatime
│ ├─/sys/kernel/security              securityfs securityfs rw,nosuid,nodev,noexec,relatime
│ ├─/sys/fs/cgroup                    tmpfs      tmpfs      ro,nosuid,nodev,noexec,mode=755
│ │ └─/sys/fs/cgroup/...
│ └─/sys/kernel/debug                 debugfs    debugfs    rw,relatime
├─/proc                               proc       proc       rw,nosuid,nodev,noexec,relatime
├─/dev                                udev       devtmpfs   rw,nosuid,relatime,size=1014856k,nr_inodes=253714,mode=755
│ └─/dev/...
├─/run                                tmpfs      tmpfs      rw,nosuid,noexec,relatime,size=205236k,mode=755
│ └─/run/lock                         tmpfs      tmpfs      rw,nosuid,nodev,noexec,relatime,size=5120k
├─/mnt/oldroot                        /dev/md0p1 ext4       rw,relatime,discard,data=ordered
└─/tmp                                tmpfs      tmpfs      rw,relatime
  └─/tmp/menhera                      tmpfs      tmpfs      rw,relatime
    └─/tmp/menhera/newrootro          /dev/loop0 squashfs   ro,relatime
```

## Thanks

  * This project is inspired by [marcan/takeover.sh](https://github.com/marcan/takeover.sh)
  * The major code came from [a maintenance writeup on my blog](https://blog.swineson.me/debian-9-csm-online-convert-root-partition-to-raid/) (in Simp. Chinese)
  * [xTom.com](https://xtom.com/) donated a VPS for my testing