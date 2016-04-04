#!/bin/bash
set -ex

source charms.reactive.sh

@when_not 'cuda.installed'
function install_cuda() {
    juju-log "Testing presence of CUDA compliant device"
    local SUPPORT_CUDA="$(lspci -nnk | grep -iA2 NVIDIA | wc -l)"

    if [ "${SUPPORT_CUDA}" = "0" ]; then
        juju-log "This instance does not run an nVidia GPU. Exiting with error"
        exit 1
    fi

    juju-log "Creating program variables"
    NVIDIA_GPGKEY_SUM="bd841d59a27a406e513db7d405550894188a4c1cd96bf8aa4f82f1b39e0b5c1c"
    NVIDIA_GPGKEY_FPR="889bee522da690103c4b085ed88c3d385c37d3be"
    CUDA_VERSION="7.5"
    CUDA_PKG_VERSION="7-5=7.5-18"

    juju-log "Adding apt repository"
    apt-key adv --fetch-keys http://developer.download.nvidia.com/compute/cuda/repos/GPGKEY && \
        apt-key adv --export --no-emit-version -a $NVIDIA_GPGKEY_FPR | tail -n +2 > cudasign.pub && \
        echo "$NVIDIA_GPGKEY_SUM cudasign.pub" | sha256sum -c --strict - && rm cudasign.pub && \
        echo "deb http://developer.download.nvidia.com/compute/cuda/repos/ubuntu1404/x86_64 /" > /etc/apt/sources.list.d/cuda.list

    juju-log "Updating repository listings"
    apt-get update -yqq && apt-get upgrade -yqq

    juju-log "Installing CUDA"
    apt-get install -yqq build-essential linux-image-extra-virtual

    apt-get update && apt-get install -y --no-install-recommends --force-yes \
        cuda-nvrtc-$CUDA_PKG_VERSION \
        cuda-cusolver-$CUDA_PKG_VERSION \
        cuda-cublas-$CUDA_PKG_VERSION \
        cuda-cufft-$CUDA_PKG_VERSION \
        cuda-curand-$CUDA_PKG_VERSION \
        cuda-cusparse-$CUDA_PKG_VERSION \
        cuda-npp-$CUDA_PKG_VERSION \
        cuda-cudart-$CUDA_PKG_VERSION \
        cuda && \
        ln -s cuda-$CUDA_VERSION /usr/local/cuda

        juju-log "Configuring libraries"
    echo "/usr/local/cuda/lib" >> /etc/ld.so.conf.d/cuda.conf && \
        echo "/usr/local/cuda/lib64" >> /etc/ld.so.conf.d/cuda.conf && \
        ldconfig

    echo "/usr/local/nvidia/lib" >> /etc/ld.so.conf.d/nvidia.conf && \
        echo "/usr/local/nvidia/lib64" >> /etc/ld.so.conf.d/nvidia.conf && \
        ldconfig

    export PATH="/usr/local/cuda/bin:${PATH}"
    echo "PATH=${PATH}" | tee /etc/environments
    export LD_LIBRARY_PATH="/usr/local/cuda/lib64:/usr/local/cuda/lib:/usr/local/nvidia/lib:/usr/local/nvidia/lib64:${LD_LIBRARY_PATH}"
    echo "LD_LIBRARY_PATH=${LD_LIBRARY_PATH}" | tee -a /etc/environments

    juju-reboot

    charms.reactive set_state 'cuda.installed'
}


reactive_handler_main
