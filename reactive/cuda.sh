#!/bin/bash
set -ex

source charms.reactive.sh

CUDA_VERSION=$(config-get cuda-version | awk 'BEGIN{FS="-"}{print $1}')
CUDA_SUB_VERSION=$(config-get cuda-version | awk 'BEGIN{FS="-"}{print $2}')
SUPPORT_CUDA="$(lspci -nnk | grep -iA2 NVIDIA | wc -l)"
ROOT_URL="http://developer.download.nvidia.com/compute/cuda/repos"

#####################################################################
#
# Basic Functions
#
#####################################################################

function bash::lib::get_ubuntu_codename() {
    lsb_release -a 2>/dev/null | grep Codename | awk '{ print $2 }'
}

UBUNTU_CODENAME="$(bash::lib::get_ubuntu_codename)"

case "$(arch)" in
    "x86_64" | "amd64" )
        ARCH="x86_64"
    ;;
    "ppc64le" | "ppc64el" )
        ARCH="ppc64le"
    ;;
    * )
        juju-log "Your architecture is not supported. Exiting"
        exit 1
    ;;
esac

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

#####################################################################
#
# Install nvidia driver per architecture
#
#####################################################################

function all:all:install_nvidia_driver() {

    apt-get remove -yqq --purge nvidia-* libcuda1-*
    apt-get install -yqq --no-install-recommends \
        nvidia-375 \
        nvidia-375-dev \
        libcuda1-375
}

function trusty::x86_64::install_nvidia_driver() {
    all:all:install_nvidia_driver
}

function xenial::x86_64::install_nvidia_driver() {
    all:all:install_nvidia_driver
}

function trusty::ppc64le::install_nvidia_driver() {
    bash::lib::log warn "This task is handled by the cuda installer"
}

function xenial::ppc64le::install_nvidia_driver() {
    bash::lib::log info "This task is handled by the cuda installer"
}

#####################################################################
#
# Install OpenBlas per architecture
#
#####################################################################

function trusty::x86_64::install_openblas() {
    apt-get update -qq
    apt-get install -yqq --no-install-recommends \
        libopenblas-base \
        libopenblas-dev
}

function xenial::x86_64::install_openblas() {
    juju-log "Not planned yet"
    apt-get install -yqq --no-install-recommends \
        libopenblas-base \
        libopenblas-dev
}

function trusty::ppc64le::install_openblas() {
    [ -d "/mnt/openblas" ] \
        || git clone https://github.com/xianyi/OpenBLAS.git /mnt/openblas \
        && { cd "/mnt/openblas" ; git pull ; cd - ; }
        cd /mnt/openblas
        make && make PREFIX=/usr install
}

function xenial::ppc64le::install_openblas() {
    apt-get install -yqq --no-install-recommends \
        libopenblas-base \
        libopenblas-dev
}

#####################################################################
#
# Install CUDA per architecture
#
#####################################################################

function all::x86_64::install_cuda() {
    INSTALL_PKG="cuda-repo-${UBUNTU_VERSION}_${CUDA_VERSION}-${CUDA_SUB_VERSION}_amd64.deb"
    cd /tmp
    [ -f ${INSTALL_PKG} ] && rm -f ${INSTALL_PKG}
    wget ${ROOT_URL}/${UBUNTU_VERSION}/x86_64/${INSTALL_PKG}
    dpkg -i /tmp/${INSTALL_PKG}
    apt-get update -qq && \
    apt-get install -yqq --allow-downgrades --allow-remove-essential --allow-change-held-packages --no-install-recommends \
        cuda
    rm -f ${INSTALL_PKG}
}

function trusty::x86_64::install_cuda() {
    all::x86_64::install_cuda
}

function xenial::x86_64::install_cuda() {
    all::x86_64::install_cuda
}

function trusty::ppc64le::install_cuda() {
    bash::lib::die This OS is not supported by nVidia for CUDA 8.0. Please upgrade to 16.04
}

function xenial::ppc64le::install_cuda() {
    wget -c -p /tmp "${ROOT_URL}/${UBUNTU_VERSION}/ppc64el/cuda-repo-${UBUNTU_VERSION}_${CUDA_VERSION}-${CUDA_SUB_VERSION}_ppc64el.deb"
    dpkg -i /tmp/cuda-repo-${UBUNTU_VERSION}_${CUDA_VERSION}-${CUDA_SUB_VERSION}_ppc64el.deb
    apt-get update -qq && \
    apt-get install -yqq --allow-downgrades --allow-remove-essential --allow-change-held-packages --no-install-recommends \
            cuda
}

#####################################################################
#
# Add CUDA libraries & paths
#
#####################################################################

function all::all::add_cuda_path() {
    ln -sf "/usr/local/cuda-$CUDA_VERSION" "/usr/local/cuda"

    # Configuring libraries
    cat > /etc/ld.so.conf.d/cuda.conf << EOF
/usr/local/cuda/lib
/usr/local/cuda/lib64
EOF

    cat > /etc/ld.so.conf.d/nvidia.conf << EOF
/usr/local/nvidia/lib
/usr/local/nvidia/lib64
EOF

    ldconfig

    cat > /etc/profile.d/cuda.sh << EOF
export PATH=/usr/local/cuda/bin:${PATH}
export LD_LIBRARY_PATH="/usr/local/cuda/lib64:/usr/local/cuda/lib:${LD_LIBRARY_PATH}"
EOF

    cat > /etc/profile.d/nvidia.sh << EOF
export PATH=/usr/local/nvidia/bin:${PATH}
export LD_LIBRARY_PATH="/usr/local/nvidia/lib:/usr/local/nvidia/lib64:${LD_LIBRARY_PATH}"
EOF

    echo "export PATH=\"/usr/local/cuda/bin:/usr/local/nvidia/bin:${PATH}\"" | tee -a ${HOME}/.bashrc
    echo "export LD_LIBRARY_PATH=\"/usr/local/cuda/lib64:/usr/local/cuda/lib:/usr/local/nvidia/lib:/usr/local/nvidia/lib64:${LD_LIBRARY_PATH}\"" | tee -a ${HOME}/.bashrc

    export PATH="/usr/local/cuda/bin:/usr/local/nvidia/bin:${PATH}"

    # fix "cannot find -lnvcuvid" when linking cuda programs
    # see: https://devtalk.nvidia.com/default/topic/769578/cuda-setup-and-installation/cuda-6-5-cannot-find-lnvcuvid/2
    if [ ! -f /usr/lib/libnvcuvid.so.1 ]; then
        ln -s /usr/lib/nvidia-375/libnvcuvid.so.1 /usr/lib/libnvcuvid.so.1
    fi
    if [ ! -f /usr/lib/libnvcuvid.so ]; then
        ln -s /usr/lib/nvidia-375/libnvcuvid.so /usr/lib/libnvcuvid.so
    fi
}

@only_once
function check_cuda_support() {
    case "${SUPPORT_CUDA}" in
        "0" )
            juju-log "This instance does not run an nVidia GPU."
        ;;
        * )
            charms.reactive set_state 'cuda.supported'
        ;;
    esac
}

@when 'cuda.supported'
@when_not 'cuda.installed'
function install_cuda() {

    apt-get update -qq
    # apt-get upgrade -yqq
    # In any case remove nouveau driver
    apt-get remove -yqq --purge libdrm-nouveau*
    # Here we also need to blacklist nouveau
    apt-get install -yqq --no-install-recommends \
        git \
        curl \
        wget \
        build-essential

    status-set maintenance "Installing CUDA"

    # This is a hack as for some reason this package fails
    dpkg --remove --force-remove-reinstreq grub-ieee1275 || juju-log "not installed yet, forcing not to install"
    apt-get -yqq autoremove

    juju-log "Installing common dependencies"
    # latest kernel doesn't have image-extra so we try only
    apt-get install -yqq  linux-image-extra-`uname -r` \
        || juju-log "linux-image-extra-`uname -r` not available. Skipping"

    # Install driver only on bare metal
    [ "${LXC_CMD}" = "0" ] && \
        ${UBUNTU_CODENAME}::${ARCH}::install_nvidia_driver || \
        juju-log "Running in a container. No need for the nVidia Driver"


    ${UBUNTU_CODENAME}::${ARCH}::install_openblas
    ${UBUNTU_CODENAME}::${ARCH}::install_cuda
    all::all::add_cuda_path

    charms.reactive set_state 'cuda.installed'
}

reactive_handler_main
