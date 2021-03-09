#!/bin/bash
set -Eeuo pipefail
# disable command path hashing as we are going to move fast and break things
set +h

# config
WORKDIR="/tmp/menhera"
ROOTFS=""

declare -A ARCH_MAP=(
    ["x86_64"]="amd64"
)

# internal global variables
OLDROOT="/"
NEWROOT=""

MACHINE_TYPE=$(uname -m)
ARCH_ID=${ARCH_MAP[$MACHINE_TYPE]:-$MACHINE_TYPE}

# fix possible PATH problems
export PATH="$PATH:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

menhera::reset_sshd_config() {
    cat > /etc/ssh/sshd_config <<EOF
PermitRootLogin yes
AcceptEnv LANG LC_*
EOF
}

# environment compatibility
menhera::__compat_restart_ssh() {
    if [ -x "$(command -v systemctl)" ]; then
        systemctl daemon-reload
        if ! systemctl restart ssh; then
            echo "SSH daemon start failed, try resetting config..."
            menhera::reset_sshd_config
            if ! systemctl restart ssh; then
                echo "SSH daemon fail to start, dropping you to a shell..."
                sh
            fi
        fi
    elif [ -x "$(command -v service)" ]; then
        if ! service ssh restart; then
            echo "SSH daemon start failed, try resetting config..."
            menhera::reset_sshd_config
            if ! service ssh restart; then
                echo "SSH daemon fail to start, dropping you to a shell..."
                sh
            fi
        fi
    else
        echo "ERROR: Cannot restart SSH server, init system not recoginzed" >&2
        exit 1
    fi
}

menhera::__compat_reload_init() {
    if [ -x "$(command -v systemctl)" ]; then
        systemctl daemon-reexec
    elif [ -x "$(command -v telinit)" ]; then
        telinit u
    else
        echo "ERROR: Cannot re-exec init, init system not recoginzed" >&2
        exit 1
    fi
}

# helper functions
# https://stackoverflow.com/a/3232082/2646069
menhera::confirm() {
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

# jobs
menhera::get_rootfs() {
    if [ -n ${ROOTFS} ]; then 
        echo "Getting rootfs URL..."

        # forgive me for parsing HTML with these shit
        # and hope it works
        ROOTFS_TIME=$(wget -qO- --show-progress "https://images.linuxcontainers.org/images/debian/buster/${ARCH_ID}/default/?C=M;O=D" | grep -oP '(\d{8}_\d{2}:\d{2})' | head -n 1)
        
        ROOTFS="https://images.linuxcontainers.org/images/debian/buster/${ARCH_ID}/default/${ROOTFS_TIME}/rootfs.squashfs"
    else 
        echo "\$ROOTFS is set to '$ROOTFS'"
    fi
}

menhera::sync_filesystem() {
    echo "Syncing..."
    sync
    sync
}

menhera::prepare_environment() {
    echo "Loading kernel modules..."
    modprobe overlay
    modprobe squashfs

    sysctl kernel.panic=10

    echo "Creating workspace in '${WORKDIR}'..."
    # workspace
    mkdir -p "${WORKDIR}"
    mount -t tmpfs -o size=100% tmpfs "${WORKDIR}"

    # new rootfs
    mkdir -p "${WORKDIR}/newroot"
    # readonly part of new rootfs
    mkdir -p "${WORKDIR}/newrootro"
    # writeable part of new rootfs
    mkdir -p "${WORKDIR}/newrootrw"
    # overlayfs workdir
    mkdir -p "${WORKDIR}/overlayfs_workdir"

    echo "Downloading temporary rootfs..."
    wget -q --show-progress -O "${WORKDIR}/rootfs.squashfs" "${ROOTFS}"
}

menhera::mount_new_rootfs() {
    echo "Mounting temporary rootfs..."
    mount -t squashfs "${WORKDIR}/rootfs.squashfs" "${WORKDIR}/newrootro"
    mount -t overlay overlay -o rw,lowerdir="${WORKDIR}/newrootro",upperdir="${WORKDIR}/newrootrw",workdir="${WORKDIR}/overlayfs_workdir" "${WORKDIR}/newroot"

    NEWROOT="${WORKDIR}/newroot"
}

menhera::install_software() {
    echo "Installing OpenSSH Server into new rootfs..."

    # disable APT cache
    echo -e 'Dir::Cache "";\nDir::Cache::archives "";' > "${NEWROOT}/etc/apt/apt.conf.d/00_disable-cache-directories"

    DEBIAN_FRONTEND=noninteractive chroot "${NEWROOT}" apt-get update -y
    DEBIAN_FRONTEND=noninteractive chroot "${NEWROOT}" apt-get -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" install -y openssh-server
}

menhera::copy_config() {
    echo "Copying important config into new rootfs..."
    ! cp -axL "${OLDROOT}/etc/resolv.conf" "${NEWROOT}/etc"
    ! cp -axr "${OLDROOT}/etc/ssh" "${NEWROOT}/etc"
    ! cp -ax "${OLDROOT}/etc/"{passwd,shadow} "${NEWROOT}/etc"
    ! cp -axr "${OLDROOT}/root/.ssh" "${NEWROOT}/root"

    chroot "${NEWROOT}" chsh -s /bin/bash root

    cat > "${NEWROOT}/etc/motd" <<EOF

Download menhera.sh at https://github.com/Jamesits/menhera.sh

!!!NOTICE!!!

This is a minimal RAM system created by menhera.sh. Feel free to format your disk, but don't blame anyone
except yourself if you lost important files or your system is broken.

If you think you've done something wrong, reboot immediately -- there is still hope.

Your original rootfs is at /mnt/oldroot. Be careful dealing with it.

Have a lot of fun...
EOF
}

menhera::swap_root() {
    echo "Swapping rootfs..."
    # prepare future mount point for our old rootfs
    mkdir -p "${WORKDIR}/newroot/mnt/oldroot"
    mount --make-rprivate /

    # swap root
    pivot_root "${WORKDIR}/newroot" "${WORKDIR}/newroot/mnt/oldroot"

    OLDROOT="/mnt/oldroot"
    NEWROOT="/"

    # move mounts
    for i in dev proc sys run; do
        if [ -d "${OLDROOT}/$i" ]; then
            mount --move "${OLDROOT}/$i" "${NEWROOT}/$i"
        fi
    done
    mount -t tmpfs -o size=100% tmpfs "${NEWROOT}/tmp"

    mkdir -p "${WORKDIR}"
    mount --move "${OLDROOT}/${WORKDIR}" "${WORKDIR}"

    echo "Restarting SSH daemon..."
    menhera::__compat_restart_ssh
}

menhera::clear_processes() {
    echo "Disabling swap..."
    swapoff -a

    echo "Restarting init process..."
    menhera::__compat_reload_init
    # hope 15s is enough
    sleep 15

    echo "Killing all programs still using the old root..."
    fuser -kvm "${OLDROOT}" -15
    # in most cases the parent process of this script will be killed, so goodbye
}

# main procedure
LIBRARY_ONLY=0

while test $# -gt 0
do
    case "$1" in
        --lib) LIBRARY_ONLY=1
            ;;
    esac
    shift
done

if [[ $LIBRARY_ONLY -eq 1 ]]; then
    # acting as a library only
    return 0
fi

if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root" 
    exit 1
fi

echo -e "We will start a temporary RAM system as your recovery environment."
echo -e "Note that this script will kill programs and umount filesystems without prompting."
echo -e "Please confirm:"
echo -e "\tYou have closed all programs you can, and backed up all important data"
echo -e "\tYou can SSH into your system as root user"
menhera::confirm || exit -1

menhera::get_rootfs
menhera::sync_filesystem

menhera::prepare_environment
menhera::mount_new_rootfs
menhera::copy_config
menhera::install_software
menhera::swap_root

echo -e "If you are connecting from SSH, please create a second session to this host use root and"
echo -e "confirm you can get a shell."
echo -e "After your confirmation, we are going to kill the old SSH server."

if menhera::confirm; then 
    menhera::clear_processes
else
    echo -e "Please manually issue a reboot to recover your old OS. If you believe there is a bug in menhera.sh, "
    echo -e "raise a ticket at https://github.com/Jamesits/menhera.sh/issues ."
    exit 1
fi
