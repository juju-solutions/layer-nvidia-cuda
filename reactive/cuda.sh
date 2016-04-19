#!/bin/bash
set -ex

source charms.reactive.sh

CUDA_VERSION="7.5"
CUDA_SUB_VERSION="18"
CUDA_PKG_VERSION="7-5"

#####################################################################
#
# Basic Functions
# 
#####################################################################

function bash::lib::get_ubuntu_codename() {
    lsb_release -a 2>/dev/null | grep Codename | awk '{ print $2 }'
}

UBUNTU_CODENAME="$(bash::lib::get_ubuntu_codename)"

#####################################################################
#
# Install nvidia driver per architecture
# 
#####################################################################

function trusty::ppc64le::install_nvidia_driver() { 
    wget -c http://us.download.nvidia.com/Ubuntu/352.88/NVIDIA-Linux-ppc64le-352.88.run -P /tmp
    sudo chmod +x /tmp/NVIDIA-Linux-ppc64le-352.88.run
    sudo /tmp/NVIDIA-Linux-ppc64le-352.88.run -a -q -s --disable-nouveau
    apt-get install -yqq --no-install-recommends --force-yes cuda-drivers nvidia-352 nvidia-352-uvm nvidia-352-dev libcuda1-352; 
}

function trusty::x86_64::install_nvidia_driver() { 
    apt-get install -yqq --no-install-recommends --force-yes cuda-drivers nvidia-352 nvidia-352-uvm nvidia-352-dev libcuda1-352; 
}

function xenial::ppc64le::install_nvidia_driver() { 
    apt-get install -yqq --no-install-recommends --force-yes cuda-drivers nvidia-352 nvidia-352-uvm nvidia-352-dev libcuda1-352; 
}

function xenial::x86_64::install_nvidia_driver() { 
    apt-get install -yqq --no-install-recommends --force-yes cuda-drivers nvidia-352 nvidia-352-uvm nvidia-352-dev libcuda1-352; 
}

#####################################################################
#
# Install OpenBlas per architecture
# 
#####################################################################

function trusty::ppc64le::install_openblas() { 
    sudo apt-get install -yqq git curl wget
    [ -d "/mnt/openblas" ] \
        || sudo git clone https://github.com/xianyi/OpenBLAS.git /mnt/openblas \
        && { cd "/mnt/openblas" ; sudo git pull ; cd - ; }
        cd /mnt/openblas
        sudo make && sudo make PREFIX=/usr install
}

function trusty::x86_64::install_openblas() { 
    apt-get update -qq 
    apt-get install -yqq --force-yes --no-install-recommends \
        libopenblas-base \
        libopenblas-dev
}

function xenial::ppc64le::install_openblas() { 
    echo "Not planned yet"
}

function xenial::x86_64::install_openblas() { 
    echo "Not planned yet"
}

#####################################################################
#
# Install CUDA per architecture
# 
#####################################################################

function trusty::ppc64le::install_cuda() { 
    wget -c -P /tmp "http://developer.download.nvidia.com/compute/cuda/7.5/Prod/local_installers/cuda-repo-ubuntu1404-7-5-local_7.5-18_ppc64el.deb"
    dpkg -i /tmp/cuda-repo-ubuntu1404-7-5-local_7.5-18_ppc64el.deb

    apt-add-repository -y ppa:openjdk-r/ppa
    apt-add-repository -y ppa:jochenkemnade/openjdk-8

    apt-get update -yqq

    # What this does is really copy all packages from CUDA into /var/cuda-repo-7-5-local
    apt-get install -yqq --no-install-recommends --force-yes \
        cuda-license-${CUDA_PKG_VERSION} \
        cuda-misc-headers-${CUDA_PKG_VERSION} \
        cuda-core-${CUDA_PKG_VERSION} \
        cuda-cudart-${CUDA_PKG_VERSION} \
        cuda-driver-dev-${CUDA_PKG_VERSION} \
        cuda-cudart-dev-${CUDA_PKG_VERSION} \
        cuda-command-line-tools-${CUDA_PKG_VERSION} \
        cuda-nvrtc-${CUDA_PKG_VERSION} \
        cuda-cusolver-${CUDA_PKG_VERSION} \
        cuda-cublas-${CUDA_PKG_VERSION} \
        cuda-cufft-${CUDA_PKG_VERSION} \
        cuda-curand-${CUDA_PKG_VERSION} \
        cuda-cusparse-${CUDA_PKG_VERSION} \
        cuda-npp-${CUDA_PKG_VERSION} \
        cuda-nvrtc-dev-${CUDA_PKG_VERSION} \
        cuda-cusolver-dev-${CUDA_PKG_VERSION} \
        cuda-cublas-dev-${CUDA_PKG_VERSION} \
        cuda-cufft-dev-${CUDA_PKG_VERSION} \
        cuda-curand-dev-${CUDA_PKG_VERSION} \
        cuda-cusparse-dev-${CUDA_PKG_VERSION} \
        cuda-npp-dev-${CUDA_PKG_VERSION} \
        cuda-samples-${CUDA_PKG_VERSION} \
        cuda-documentation-${CUDA_PKG_VERSION} \
        cuda-visual-tools-${CUDA_PKG_VERSION} \
        cuda-toolkit-${CUDA_PKG_VERSION} \
        cuda
}

function trusty::x86_64::install_cuda() { 
    NVIDIA_GPGKEY_SUM="bd841d59a27a406e513db7d405550894188a4c1cd96bf8aa4f82f1b39e0b5c1c"
    NVIDIA_GPGKEY_FPR="889bee522da690103c4b085ed88c3d385c37d3be"

    apt-key adv --fetch-keys http://developer.download.nvidia.com/compute/cuda/repos/GPGKEY && \
        apt-key adv --export --no-emit-version -a $NVIDIA_GPGKEY_FPR | tail -n +2 > cudasign.pub && \
        echo "$NVIDIA_GPGKEY_SUM cudasign.pub" | sha256sum -c --strict - && rm cudasign.pub && \
        echo "deb http://developer.download.nvidia.com/compute/cuda/repos/ubuntu1404/x86_64 /" > /etc/apt/sources.list.d/cuda.list

    apt-get update -yqq

    apt-get install -yqq --no-install-recommends --force-yes \
        cuda-nvrtc-${CUDA_PKG_VERSION} \
        cuda-cusolver-${CUDA_PKG_VERSION} \
        cuda-cublas-${CUDA_PKG_VERSION} \
        cuda-cufft-${CUDA_PKG_VERSION} \
        cuda-curand-${CUDA_PKG_VERSION} \
        cuda-cusparse-${CUDA_PKG_VERSION} \
        cuda-npp-${CUDA_PKG_VERSION} \
        cuda-cudart-${CUDA_PKG_VERSION} \
        cuda
}

function xenial::ppc64le::install_cuda() { 
    echo "Not planned yet"

}

function xenial::x86_64::install_cuda() { 
    echo "Not planned yet"

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
export LD_LIBRARY_PATH=${LD_LIBRARY_PATH}
EOF

    echo "export PATH=\"/usr/local/cuda/bin:${PATH}\"" | tee -a ${HOME}/.bashrc
    echo "export LD_LIBRARY_PATH=\"/usr/local/cuda/lib64:/usr/local/cuda/lib:/usr/local/nvidia/lib:/usr/local/nvidia/lib64:${LD_LIBRARY_PATH}\"" | tee -a ${HOME}/.bashrc

    export PATH="/usr/local/cuda/bin:${PATH}"
    export LD_LIBRARY_PATH="/usr/local/cuda/lib64:/usr/local/cuda/lib:/usr/local/nvidia/lib:/usr/local/nvidia/lib64:${LD_LIBRARY_PATH}"

}

# @hook 'install'
@when_not 'cuda.installed'
function install_cuda() {
    # charms.reactive unset_state 'cuda.installed'
    status-set maintenance "Installing CUDA"
    juju-log "Testing presence of CUDA compliant device"
    local SUPPORT_CUDA="$(lspci -nnk | grep -iA2 NVIDIA | wc -l)"

    if [ "${SUPPORT_CUDA}" = "0" ]; then
        juju-log "This instance does not run an nVidia GPU. You will be able to compile CUDA Apps but not use CUDA"
    fi

    juju-log "Installing common dependencies"
    apt-get update -yqq && apt-get upgrade -yqq
    apt-get install -yqq build-essential linux-image-extra-`uname -r`

    case "$(arch)" in 
        "x86_64" | "amd64" )
            ARCH="x86_64"
        ;;
        "ppc64le" )
            ARCH="$(arch)" 
        ;;
        * )
            juju-log "Your version of Ubuntu is not supported. Exiting"
            exit 1
        ;;
    esac

    case "${UBUNTU_CODENAME}" in 
        "trusty" )
            LXC_CMD="$(running-in-container | grep lxc | wc -l)"
        ;;
        "xenial" )
            LXC_CMD="$(systemd-detect-virt --container | grep lxc | wc -l)"
        ;;
        * )
            juju-log "Your version of Ubuntu is not supported. Exiting"
            exit 1
        ;;
    esac

    ${UBUNTU_CODENAME}::${ARCH}::install_openblas
    ${UBUNTU_CODENAME}::${ARCH}::install_cuda
    all::all::add_cuda_path

    # Installing driver only on bare metal
    [ "${LXC_CMD}" = "0" ] && ${UBUNTU_CODENAME}::${ARCH}::install_nvidia_driver

    status-set waiting "Waiting for reboot"
    charms.reactive set_state 'cuda.installed'
}

@when 'cuda.installed'
@when_not 'cuda.available'
function reboot() {

    juju-reboot

    export PATH="/usr/local/cuda/bin:${PATH}"
    echo "PATH=${PATH}" | tee /etc/environments
    export LD_LIBRARY_PATH="/usr/local/cuda/lib64:/usr/local/cuda/lib:/usr/local/nvidia/lib:/usr/local/nvidia/lib64:${LD_LIBRARY_PATH}"
    echo "LD_LIBRARY_PATH=${LD_LIBRARY_PATH}" | tee -a /etc/environments

    status-set active "CUDA drivers installed and available"
    charms.reactive set_state 'cuda.available'
}

reactive_handler_main
