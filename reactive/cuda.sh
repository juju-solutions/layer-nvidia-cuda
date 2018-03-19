#!/bin/bash
set -e

source charms.reactive.sh

CUDA_VERSION=$(config-get cuda-version | awk 'BEGIN{FS="-"}{print $1}')
CUDA_SUB_VERSION=$(config-get cuda-version | awk 'BEGIN{FS="-"}{print $2}')
LAYER_BLACKLIST_CONF="/etc/modprobe.d/blacklist-layer-nvidia-cuda.conf"
ROOT_URL="http://developer.download.nvidia.com/compute/cuda/repos"
SUPPORT_CUDA="$(lspci -nnk | grep -iA2 NVIDIA | wc -l)"

#####################################################################
#
# Basic Functions
#
#####################################################################

function bash::lib::get_ubuntu_codename() {
    lsb_release -a 2>/dev/null | grep Codename | awk '{ print $2 }'
}

UBUNTU_CODENAME="$(bash::lib::get_ubuntu_codename)"

case "${UBUNTU_CODENAME}" in
    "trusty" )
        LXC_CMD="$(running-in-container | grep lxc | wc -l)"
        UBUNTU_VERSION=ubuntu1404
    ;;
    "xenial" )
        LXC_CMD="$(systemd-detect-virt --container | grep lxc | wc -l)"
        UBUNTU_VERSION=ubuntu1604
    ;;
    * )
        juju-log "Your version of Ubuntu is not supported. Exiting"
        exit 1
    ;;
esac

case "$(arch)" in
    "x86_64" | "amd64" )
        ARCH="x86_64"
        REPO_PKG="cuda-repo-${UBUNTU_VERSION}_${CUDA_VERSION}-${CUDA_SUB_VERSION}_amd64.deb"
        REPO_URL="${ROOT_URL}/${UBUNTU_VERSION}/x86_64/${REPO_PKG}"
    ;;
    "ppc64le" | "ppc64el" )
        ARCH="ppc64le"
        REPO_PKG="cuda-repo-${UBUNTU_VERSION}_${CUDA_VERSION}-${CUDA_SUB_VERSION}_ppc64el.deb"
        REPO_URL="${ROOT_URL}/${UBUNTU_VERSION}/ppc64el/${REPO_PKG}"
    ;;
    * )
        juju-log "Your architecture is not supported. Exiting"
        exit 1
    ;;
esac


#####################################################################
#
# Handle prerequisite steps
#
#####################################################################

function all::all::prereqs() {
    # Blacklist the nouveau module, which conflicts with nvidia.
    # NB: do not remove nouveau pkgs because of the many x11/openjdk deps. For
    # example, removing libdrm-nouveau* also removes openjdk-8-[jre|jdk].
    #   BAD: apt-get remove -yqq --purge libdrm-nouveau*
    #        apt-get -yqq autoremove
    #   GOOD: unload and blacklist the module
    juju-log "Blacklisting nouveau module"
    modprobe --remove nouveau || \
        juju-log "No nouveau module was found. No modprobe action is needed."
    cat > ${LAYER_BLACKLIST_CONF} <<EOF
blacklist nouveau
blacklist lbm-nouveau
options nouveau modeset=0
alias nouveau off
alias lbm-nouveau off
EOF
    # update the initramfs since we altered our module blacklist
    update-initramfs -u

    juju-log "Installing linux-image-extra"
    # some kernels do not have an -extra subpackage; proceed anyway
    apt-get install -yqq  linux-image-extra-`uname -r` || \
        juju-log "linux-image-extra-`uname -r` not available. Skipping"
}


#####################################################################
#
# Install CUDA per architecture
#
#####################################################################

function all::all::install_cuda_drivers() {
    ##remove any nvidia-* or libcuda1-* packages that aren't held
    ## the nvidia-docker binary needs to held to resist this
    ## but the awk means apt will play nicely with that
    PCKGS=`dpkg -l | awk '$2~/^nvidia-/|| $2~/^libcuda1-/{if($1!~/^h/){printf " "$2}}'`
    if [ -n "$PCKGS" ]; then
        juju-log "removing $PCKGS"
        apt-get remove --ignore-hold -yqq --purge $PCKGS
    fi

    cd /tmp
    [ -f ${REPO_PKG} ] && rm -f ${REPO_PKG}
    wget ${REPO_URL}
    dpkg -i /tmp/${REPO_PKG}
    apt-get update -qq && \
    apt-get install -yqq --allow-downgrades --allow-remove-essential --allow-change-held-packages --no-install-recommends \
        cuda-drivers
    rm -f ${REPO_PKG}
}

function trusty::x86_64::install_cuda_drivers() {
    all::all::install_cuda_drivers
}

function xenial::x86_64::install_cuda_drivers() {
    all::all::install_cuda_drivers
}

function trusty::ppc64le::install_cuda_drivers() {
    bash::lib::die This OS is not supported.
}

function xenial::ppc64le::install_cuda_drivers() {
    all::all::install_cuda_drivers
}

#####################################################################
#
# Remove CUDA configuration
#
#####################################################################

function all::all::remove_cuda_config() {
    # remove system config files created by this layer
    [ -f ${LAYER_BLACKLIST_CONF} ] && rm -f ${LAYER_BLACKLIST_CONF}

    # update the initramfs since we altered our module blacklist
    update-initramfs -u
}

#####################################################################
#
# Reactive Handlers
#
#####################################################################

@when_not 'cuda.supported'
function check_cuda_support() {
    case "${SUPPORT_CUDA}" in
        "0" )
            juju-log "This unit does not run an nVidia GPU."
        ;;
        * )
            charms.reactive set_state 'cuda.supported'
        ;;
    esac
}

@when 'cuda.supported'
@when_not 'cuda.installed'
function install_cuda() {
    # Return if we're configured to skip installation
    INSTALL=$(config-get install-cuda)
    if [ $INSTALL = False ]; then
      juju-log "Skip cuda-drivers installation"
      return
    fi

    status-set maintenance "Installing CUDA drivers"
    all::all::prereqs

    # Skip cuda driver installation in lxd deployments
    if [ "${LXC_CMD}" = "0" ]; then
        juju-log "Installing the nVidia driver"
        ${UBUNTU_CODENAME}::${ARCH}::install_cuda_drivers
    else
        juju-log "Running in a container. No need for the nVidia cuda drivers"
    fi

    status-set active "CUDA drivers installed"
    charms.reactive set_state 'cuda.installed'
}

@when 'cuda.installed'
@when 'config.changed.cuda-version'
function config_cuda_version() {
    # Remove config and reinstall if a new cuda-repo version is configured
    if dpkg -l cuda-repo-* 2>/dev/null | grep -q "${CUDA_VERSION}"; then
        juju-log "cuda-repo-${CUDA_VERSION} is already installed"
    else
        juju-log "Reinstalling with new CUDA version"
        all::all::remove_cuda_config
        ${UBUNTU_CODENAME}::${ARCH}::install_cuda_drivers
    fi
}

@when 'cuda.installed'
@when 'config.changed.install-cuda'
function config_cuda_install() {
    # Remove config if user sets install-cuda to false
    INSTALL=$(config-get install-cuda)
    if [ $INSTALL = False ]; then
        juju-log "Removing CUDA configuration"
        all::all::remove_cuda_config
        charms.reactive remove_state 'cuda.installed'
    fi
}

reactive_handler_main
