#!/bin/bash
set -ex

source charms.reactive.sh

function bash::lib::get_ubuntu_codename() {
    lsb_release -a 2>/dev/null | grep Codename | awk '{ print $2 }'
}

UBUNTU_CODENAME="$(bash::lib::get_ubuntu_codename)"

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

    juju-log "Creating program variables"
    CUDA_VERSION="7.5"
    CUDA_SUB_VERSION="18"
    CUDA_PKG_VERSION="7-5"

    juju-log "Installing common dependencies"


    apt-get update -yqq && apt-get upgrade -yqq
    apt-get install -yqq build-essential linux-image-extra-virtual linux-image-extra-`uname -r`

    case "$(arch)" in 
        "x86_64" ) 
            case "${UBUNTU_CODENAME}" in 
                "trusty" ) 
                    NVIDIA_GPGKEY_SUM="bd841d59a27a406e513db7d405550894188a4c1cd96bf8aa4f82f1b39e0b5c1c"
                    NVIDIA_GPGKEY_FPR="889bee522da690103c4b085ed88c3d385c37d3be"


                    juju-log "Adding apt repository"
                    apt-key adv --fetch-keys http://developer.download.nvidia.com/compute/cuda/repos/GPGKEY && \
                        apt-key adv --export --no-emit-version -a $NVIDIA_GPGKEY_FPR | tail -n +2 > cudasign.pub && \
                        echo "$NVIDIA_GPGKEY_SUM cudasign.pub" | sha256sum -c --strict - && rm cudasign.pub && \
                        echo "deb http://developer.download.nvidia.com/compute/cuda/repos/ubuntu1404/x86_64 /" > /etc/apt/sources.list.d/cuda.list

                    juju-log "Updating repository listings"
                    apt-get update -yqq

                    juju-log "Installing CUDA"

                    apt-get update -qq && \
                    apt-get install -yqq --no-install-recommends --force-yes \
                        libopenblas-base \
                        libopenblas-dev \
                        cuda-nvrtc-${CUDA_PKG_VERSION} \
                        cuda-cusolver-${CUDA_PKG_VERSION} \
                        cuda-cublas-${CUDA_PKG_VERSION} \
                        cuda-cufft-${CUDA_PKG_VERSION} \
                        cuda-curand-${CUDA_PKG_VERSION} \
                        cuda-cusparse-${CUDA_PKG_VERSION} \
                        cuda-npp-${CUDA_PKG_VERSION} \
                        cuda-cudart-${CUDA_PKG_VERSION}

                    [ "$(running-in-container)" = "lxc" ] || { apt-get install -yqq --no-install-recommends --force-yes cuda nvidia-352 nvidia-352-uvm nvidia-352-dev libcuda1-352; }
                ;;
                "xenial" )
                    juju-log "Not implemented Xenial packages for now. Exiting"
                    exit 1
                    # systemd-detect-virt --container -q
                ;;
                * )
                    juju-log "Your version of Ubuntu is not supported. Exiting"
                    exit 1
                ;;
            esac
        ;;
        "ppc64le" ) 
            case "${UBUNTU_CODENAME}" in 
                "trusty" ) 
                    MD5="af735cee83d5c80f0b7b1f84146b4614"
                    wget -c -P /tmp "http://developer.download.nvidia.com/compute/cuda/7.5/Prod/local_installers/cuda-repo-ubuntu1404-7-5-local_7.5-18_ppc64el.deb"



                    wget -c http://us.download.nvidia.com/Ubuntu/352.88/NVIDIA-Linux-ppc64le-352.88.run -P /tmp
                    chmod +x /tmp/NVIDIA-Linux-ppc64le-352.88.run
                    /tmp/NVIDIA-Linux-ppc64le-352.88.run -a --update -q -s --disable-nouveau \
                        || /tmp/NVIDIA-Linux-ppc64le-352.88.run -a -q -s --disable-nouveau \
                        || { juju-log "OK, not installing drivers"; 


                    apt-add-repository -y ppa:openjdk-r/ppa
                    apt-add-repository -y ppa:jochenkemnade/openjdk-8

                    apt-get update -yqq

                    # Install CUDA dependencies manually
                    apt-get install -yqq \
                        openjdk-8-jre openjdk-8-jre-headless java-common \
                        ca-certificates default-jre-headless fonts-dejavu-extra \
                        freeglut3 freeglut3-dev \
                        libatk-wrapper-java libatk-wrapper-java-jni \
                        libdrm-dev libgl1-mesa-dev libglu1-mesa-dev libgnomevfs2-0 libgnomevfs2-common \
                        libice-dev libpthread-stubs0-dev libsctp1 libsm-dev libx11-dev \
                        libx11-doc libx11-xcb-dev libxau-dev libxcb-dri2-0-dev libxcb-dri3-dev \
                        libxcb-glx0-dev libxcb-present-dev libxcb-randr0-dev libxcb-render0-dev \
                        libxcb-shape0-dev libxcb-sync-dev libxcb-xfixes0-dev libxcb1-dev \
                        libxdamage-dev libxdmcp-dev libxext-dev libxfixes-dev libxi-dev \
                        libxmu-dev libxmu-headers libxshmfence-dev libxt-dev libxxf86vm-dev \
                        x11proto-core-dev x11proto-damage-dev x11proto-dri2-dev x11proto-fixes-dev x11proto-gl-dev \
                        x11proto-kb-dev x11proto-xext-dev x11proto-xf86vidmode-dev x11proto-input-dev \
                        xorg-sgml-doctools xtrans-dev libgles2-mesa-dev \
                        lksctp-tools mesa-common-dev build-essential

                    [ -d "/mnt/openblas" ] \
                        || git clone https://github.com/xianyi/OpenBLAS.git /mnt/openblas \
                        && { cd "/mnt/openblas" ; git pull origin master ; cd - ; }
                        cd /mnt/openblas
                        make && make PREFIX=/usr install

                    dpkg -i /tmp/cuda-repo-ubuntu1404-7-5-local_7.5-18_ppc64el.deb
                    # What this does is really copy all packages from CUDA into /var/cuda-repo-7-5-local
                    apt-get update -qq 
                    apt-get install -yqq cuda-license cuda-misc-headers cuda-core cuda-cudart cuda-driver-dev cuda-cudart-dev cuda-command-line-tools \
                        cuda-nvrtc cuda-cusolver cuda-cublas cuda-cufft cuda-curand cuda-cusparse cuda-npp \
                        cuda-nvrtc-dev cuda-cusolver-dev cuda-cublas-dev cuda-cufft-dev cuda-curand-dev cuda-cusparse-dev cuda-npp-dev \
                        cuda-samples cudata-documentation cuda-visual-tools cuda-toolkit

                    # If running in a container, no need for the driver itself, toolkit is sufficient
                    [ "$(running-in-container)" = "lxc" ] || \
                        apt-get install -yqq --no-install-recommends --force-yes cuda cuda-drivers nvidia-352 nvidia-352-uvm nvidia-352-dev libcuda1-352
                ;;
                "xenial" )
                    juju-log "Not implemented Xenial packages for now. Exiting"
                    exit 1
                    # If running in a container, no need for the driver itself, toolkit is sufficient
                    # systemd-detect-virt --container -q
                ;;
                * )
                    juju-log "Your version of Ubuntu is not supported. Exiting"
                    exit 1
                    # Note: this doesn't cover the installation of the CUDA driver on the host. Another charm? 
                    # dpkg -i /var/cuda-repo-${CUDA_PKG_VERSION}-local/nvidia-352_352.39-0ubuntu1_$(arch).deb
                ;;
            esac
        ;;
    esac

    ln -sf "/usr/local/cuda-$CUDA_VERSION" "/usr/local/cuda"

    juju-log "Configuring libraries"
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

    chmod +x /etc/profile.d/cuda.sh

    echo "export PATH=\"/usr/local/cuda/bin:${PATH}\"" | tee -a ${HOME}/.bashrc
    echo "export LD_LIBRARY_PATH=\"/usr/local/cuda/lib64:/usr/local/cuda/lib:/usr/local/nvidia/lib:/usr/local/nvidia/lib64:${LD_LIBRARY_PATH}\"" | tee -a ${HOME}/.bashrc

    export PATH="/usr/local/cuda/bin:${PATH}"
    export LD_LIBRARY_PATH="/usr/local/cuda/lib64:/usr/local/cuda/lib:/usr/local/nvidia/lib:/usr/local/nvidia/lib64:${LD_LIBRARY_PATH}"

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
