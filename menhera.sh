#!/bin/bash
set -Eeuo pipefail

# config
WORKDIR="/tmp/menhera"
ROOTFS="https://images.linuxcontainers.org/images/debian/stretch/amd64/default/20190409_05:24/rootfs.squashfs"

# internal global variables
OLDROOT="/"
NEWROOT=""

# https://stackoverflow.com/a/3232082/2646069
confirm() {
    # call with a prompt string or use a default
    read -r -p "${1:-Are you sure? [y/N]} " response
    case "$response" in
        [yY][eE][sS]|[yY]) 
            true
            ;;
        *)
            false
            ;;
    esac
}

sync_filesystem() {
    echo "Syncing..."
    sync
    sync
}

prepare_environment() {
    echo "Loading kernel modules..."
    modprobe overlay
    modprobe squashfs

    echo "Creating workspace in '${WORKDIR}'..."
    # workspace
    mkdir -p "${WORKDIR}"
    mount -t tmpfs tmpfs "${WORKDIR}"

    # new rootfs
    mkdir -p "${WORKDIR}/newroot"
    # readonly part of new rootfs
    mkdir -p "${WORKDIR}/newrootro"
    # writeable part of new rootfs
    mkdir -p "${WORKDIR}/newrootrw"
    # overlayfs workdir
    mkdir -p "${WORKDIR}/overlayfs_workdir"

    echo "Downloading temporary rootfs..."
    wget -c "${ROOTFS}" -O "${WORKDIR}/rootfs.squashfs"
}

mount_new_rootfs() {
    echo "Mounting temporary rootfs..."
    mount -t squashfs "${WORKDIR}/rootfs.squashfs" "${WORKDIR}/newrootro"
    mount -t overlay overlay -o rw,lowerdir="${WORKDIR}/newrootro",upperdir="${WORKDIR}/newrootrw",workdir="${WORKDIR}/overlayfs_workdir" "${WORKDIR}/newroot"

    NEWROOT="${WORKDIR}/newroot"
}

install_software() {
    echo "Installing OpenSSH Server into new rootfs..."
    DEBIAN_FRONTEND=noninteractive chroot "${NEWROOT}" apt-get update -y
    DEBIAN_FRONTEND=noninteractive chroot "${NEWROOT}" apt-get -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" install -y ssh
}

copy_config() {
    echo "Copying important config into new rootfs..."
    ! cp -ax "${OLDROOT}/etc/resolv.conf" "${NEWROOT}/etc"
    ! cp -axr "${OLDROOT}/etc/ssh" "${NEWROOT}/etc"
    ! cp -ax "${OLDROOT}/etc/"{passwd,shadow} "${NEWROOT}/etc"
    ! cp -axr "${OLDROOT}/root/.ssh" "${NEWROOT}/root"

    chroot "${NEWROOT}" chsh -s /bin/bash root

    cat > "${NEWROOT}/etc/motd" <<EOF
NOTICE

This is a minimal RAM system created by menhera.sh. Feel free to format your disk, but don't blame anyone
except yourself if you lost important files or your system is broken.

Download menhera.sh at https://github.com/Jamesits/menhera.sh

Have a lot of fun...
EOF
}

swap_root() {
    echo "Swapping rootfs..."
    # prepare future mount point for our old rootfs
    mkdir -p "${WORKDIR}/newroot/mnt/oldroot"
    mount --make-rprivate /

    # swap root
    pivot_root "${WORKDIR}/newroot" "${WORKDIR}/newroot/mnt/oldroot"

    OLDROOT="/mnt/oldroot"
    NEWROOT="/"

    # move mounts
    for i in dev proc sys run; do mount --move "${OLDROOT}/$i" "${NEWROOT}/$i"; done
    mount -t tmpfs tmpfs "${NEWROOT}/tmp"

    mkdir -p "${WORKDIR}"
    mount --move "${OLDROOT}/${WORKDIR}" "${WORKDIR}"

    echo "Restarting SSH daemon..."
    systemctl restart ssh
}

clear_processes() {
    echo "Disabling swap..."
    swapoff -a

    echo "Restarting systemd..."
    systemctl daemon-reexec --no-block
    sleep 15

    echo "Killing all programs still using the old root..."
    fuser -kvm "${OLDROOT}" -15
    # in most cases the parent process of this script will be killed, so goodbye
}

if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root" 
    exit 1
fi

echo -e "We will start a temporary RAM system as your recovery environment."
echo -e "Note that this script will kill programs and umount filesystems without prompting."
echo -e "Please confirm:"
echo -e "\tYou have closed all programs you can, and backed up all important data"
echo -e "\tYou can SSH into your system as root user"
confirm || exit -1

sync_filesystem

prepare_environment
mount_new_rootfs
copy_config
install_software
swap_root

echo -e "If you are connecting from SSH, please create a second session to this host and confirm you can get a shell."
echo -e "After your confirmation, we are going to kill the old SSH server."
confirm || exit -1

clear_processes
