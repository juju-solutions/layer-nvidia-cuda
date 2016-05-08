#!/bin/bash
set -ex

source charms.reactive.sh

CUDA_VERSION="7.5"
CUDA_SUB_VERSION="18"
CUDA_PKG_VERSION="7-5"
NVIDIA_DRIVER_VERSION="352.88"
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

case "$(arch)" in
    "x86_64" | "amd64" )
        ARCH="x86_64"
    ;;
    "ppc64le" | "ppc64el" )
        ARCH="ppc64le"
        # The checksum of the gdk installer.
        NVIDIA_GDK_INSTALLER_SUM="064678e29d39f0c21f4b66c5e2fb18ba65fd9bc3372d0b319c31cab0e791fc1c"
    ;;
    * )
        juju-log "Your architecture is not supported. Exiting"
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

#####################################################################
#
# Install nvidia GDK per architecture
# 
#####################################################################

function all:all:install_nvidia_gdk() {
    NVIDIA_GDK_INSTALL_PATH="/opt/nvidia-gdk"
    NVIDIA_GDK_CONF_FILE="/etc/ld.so.conf.d/nvidia-gdk.conf"
    NVIDIA_GDK_INSTALLER_URL="http://developer.download.nvidia.com/compute/cuda/${CUDA_VERSION}/Prod/gdk/gdk_linux_${ARCH}_352_79_release.run"

    if [ ! -d "${NVIDIA_GDK_INSTALL_PATH}" ]; then
      mkdir -p "${NVIDIA_GDK_INSTALL_PATH}"
    fi
    if [ ! -d "${NVIDIA_GDK_INSTALL_PATH}" ] ||
       [ ! -w "${NVIDIA_GDK_INSTALL_PATH}" ]; then
      juju-log "Error: Inaccessible path: ${NVIDIA_GDK_INSTALL_PATH}"
      juju-log "       The installation directory is either inaccessable or"
      juju-log "       cannot be created because you do not have the proper"
      juju-log "       permissions to access it. Please select a different"
      juju-log "       location, or rerun this command as a user with the"
      juju-log "       proper permissions, e.g. using ''."
      exit 1;
    fi

    # Create a place for storing temporary files and make sure this
    # directory gets deleted whenever this script exits.
    NVIDIA_TEMP_DIR=$(mktemp -d)
    trap "rm -rf ${NVIDIA_TEMP_DIR}" EXIT

    # Download and run the Nvidia GDK installer.
    NVIDIA_GDK_INSTALLER_FILE="${NVIDIA_TEMP_DIR}/gdk"

    wget -O ${NVIDIA_GDK_INSTALLER_FILE} -q ${NVIDIA_GDK_INSTALLER_URL}
    RESULT="${?}"

    if [ ${RESULT} != "0" ]; then
      juju-log "Failed to download the installer!"
      juju-log "Error running wget, please check your internet connection:"
      juju-log "  \$ wget ${NVIDIA_GDK_INSTALLER_URL}"
      exit ${RESULT}
    fi

    juju-log "${NVIDIA_GDK_INSTALLER_SUM}  ${NVIDIA_GDK_INSTALLER_FILE}" \
        | sha256sum -c --strict -
    RESULT="${?}"

    if [ ${RESULT} != "0" ]; then
      juju-log "Failed verifying the checksum of the downloaded Nvidia GDK installer!"
      juju-log "Please report this error to dev@mesos.apache.org."
      exit ${RESULT}
    fi

    # Remove a symbolic link so that running this script is idempotent.
    # Without removing this symbolic link, the GDK installer script errors
    # out with the line:
    #   'ln: failed to create symbolic link <path_to_file>: File exists'
    # Since we know the next thing we will do is run the installer,
    # manually removing this file should be harmless.
    rm -rf ${NVIDIA_GDK_INSTALL_PATH}/usr/bin/nvvs

    # Run the installer.
    # We pass the '--silent' flag here to make the GDK installer happy.
    # Without it, it errors out with the line:
    #  'The installer must be run in silent mode to use command-line options.'
    chmod +x "${NVIDIA_GDK_INSTALLER_FILE}"
    ${NVIDIA_GDK_INSTALLER_FILE} --installdir="${NVIDIA_GDK_INSTALL_PATH}" --silent

    # Optionally update the ld cache with the Nvidia GDK library path.
    cat > ${NVIDIA_GDK_CONF_FILE} << EOF
# nvidia-gdk default configuration
${NVIDIA_GDK_INSTALL_PATH}/usr/src/gdk/nvml/lib/
EOF

    ldconfig
    juju-log "Wrote '${NVIDIA_GDK_CONF_FILE}' and ran ldconfig"
}

function trusty::x86_64::install_nvidia_gdk() { 
    # The checksum of the gdk installer.
    NVIDIA_GDK_INSTALLER_SUM="3fa9d17cd57119d82d4088e5cfbfcad960f12e3384e3e1a7566aeb2441e54ce4"
    all::all:install_nvidia_gdk
}

function xenial::x86_64::install_nvidia_gdk() { 
    # The checksum of the gdk installer.
    NVIDIA_GDK_INSTALLER_SUM="3fa9d17cd57119d82d4088e5cfbfcad960f12e3384e3e1a7566aeb2441e54ce4"
    all::all:install_nvidia_gdk
}

function trusty::ppc64le::install_nvidia_gdk() { 
    # The checksum of the gdk installer.
    NVIDIA_GDK_INSTALLER_SUM="064678e29d39f0c21f4b66c5e2fb18ba65fd9bc3372d0b319c31cab0e791fc1c"
    all::all:install_nvidia_gdk
}

function xenial::ppc64le::install_nvidia_gdk() { 
    # The checksum of the gdk installer.
    NVIDIA_GDK_INSTALLER_SUM="064678e29d39f0c21f4b66c5e2fb18ba65fd9bc3372d0b319c31cab0e791fc1c"
    all::all:install_nvidia_gdk
}

#####################################################################
#
# Install nvidia driver per architecture
# 
#####################################################################

function all:all:install_nvidia_driver() {
    apt-get install -yqq --no-install-recommends --force-yes \
        cuda-drivers \
        nvidia-352 \
        nvidia-352-uvm \
        nvidia-352-dev \
        libcuda1-352
}

function trusty::x86_64::install_nvidia_driver() { 
    all:all:install_nvidia_driver
}

function xenial::x86_64::install_nvidia_driver() { 
    all:all:install_nvidia_driver
}

function trusty::ppc64le::install_nvidia_driver() { 
    wget -c http://us.download.nvidia.com/Ubuntu/"${NVIDIA_DRIVER_VERSION}"/NVIDIA-Linux-"${ARCH}"-"${NVIDIA_DRIVER_VERSION}".run -P /tmp
    chmod +x /tmp/NVIDIA-Linux-"${ARCH}"-"${NVIDIA_DRIVER_VERSION}".run
    /tmp/NVIDIA-Linux-"${ARCH}"-"${NVIDIA_DRIVER_VERSION}".run -a -q -s --disable-nouveau
    all:all:install_nvidia_driver
}

function xenial::ppc64le::install_nvidia_driver() { 
    all:all:install_nvidia_driver
}

#####################################################################
#
# Install OpenBlas per architecture
# 
#####################################################################

function trusty::ppc64le::install_openblas() { 
    [ -d "/mnt/openblas" ] \
        || git clone https://github.com/xianyi/OpenBLAS.git /mnt/openblas \
        && { cd "/mnt/openblas" ; git pull ; cd - ; }
        cd /mnt/openblas
        make && make PREFIX=/usr install
}

function trusty::x86_64::install_openblas() { 
    apt-get update -qq 
    apt-get install -yqq --force-yes --no-install-recommends \
        libopenblas-base \
        libopenblas-dev
}

function xenial::ppc64le::install_openblas() { 
    apt-get install -yqq --force-yes --no-install-recommends \
        libopenblas-base \
        libopenblas-dev
}

function xenial::x86_64::install_openblas() { 
    juju-log "Not planned yet"
}

#####################################################################
#
# Install CUDA per architecture
# 
#####################################################################

function all::all::install_cuda() { 
   apt-get update -yqq

    # What this does is really copy all packages from CUDA into /var/cuda-repo-7-5-local
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

function trusty::x86_64::install_cuda() { 
    NVIDIA_GPGKEY_SUM="bd841d59a27a406e513db7d405550894188a4c1cd96bf8aa4f82f1b39e0b5c1c"
    NVIDIA_GPGKEY_FPR="889bee522da690103c4b085ed88c3d385c37d3be"

    apt-key adv --fetch-keys http://developer.download.nvidia.com/compute/cuda/repos/GPGKEY && \
        apt-key adv --export --no-emit-version -a $NVIDIA_GPGKEY_FPR | tail -n +2 > cudasign.pub && \
        echo "$NVIDIA_GPGKEY_SUM cudasign.pub" | sha256sum -c --strict - && rm cudasign.pub && \
        echo "deb http://developer.download.nvidia.com/compute/cuda/repos/ubuntu1404/x86_64 /" > /etc/apt/sources.list.d/cuda.list

    all::all::install_cuda

}

function xenial::x86_64::install_cuda() { 
    juju-log "Not planned yet. Trying Trusty method"
    trusty::${ARCH}::install_cuda
}

function trusty::ppc64le::install_cuda() { 
    wget -c -P /tmp "http://developer.download.nvidia.com/compute/cuda/${CUDA_VERSION}/Prod/local_installers/cuda-repo-ubuntu1404-${CUDA_PKG_VERSION}-local_${CUDA_VERSION}-${CUDA_SUB_VERSION}_ppc64el.deb"
    dpkg -i /tmp/cuda-repo-ubuntu1404-${CUDA_PKG_VERSION}-local_${CUDA_VERSION}-${CUDA_SUB_VERSION}_ppc64el.deb

    apt-add-repository -y ppa:openjdk-r/ppa
    apt-add-repository -y ppa:jochenkemnade/openjdk-8

    all::all::install_cuda
}

function xenial::ppc64le::install_cuda() { 
    juju-log "Not planned yet. Trying Trusty method"
    trusty::${ARCH}::install_cuda
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

}

# @hook 'install'
@when_not 'cuda.installed'
function install_cuda() {

    apt-get update -qq 
    apt-get upgrade -yqq
    # In any case remove nouveau driver
    apt-get remove -yqq --purge libdrm-nouveau* 
    # Here we also need to blacklist nouveau
    apt-get install -yqq --force-yes --no-install-recommends \
        git \
        curl \
        wget \
        build-essential

    # charms.reactive unset_state 'cuda.installed'
    status-set maintenance "Installing CUDA"

    juju-log "Testing presence of CUDA compliant device"
    case "${SUPPORT_CUDA}" in 
        "0" ) 
            juju-log "This instance does not run an nVidia GPU. You will be able to compile CUDA Apps but not use CUDA"
            NVIDIA_GDK_INSTALL_PATH="/opt/nvidia-gdk"
            NVIDIA_GDK_CONF_FILE="/etc/ld.so.conf.d/nvidia-gdk.conf"
            ${UBUNTU_CODENAME}::${ARCH}::install_nvidia_gdk
            # Add code to install the GDK
        ;;
        * )
            # This is a hack as for some reason this package fails
            dpkg --remove --force-remove-reinstreq grub-ieee1275 || juju-log "not installed yet, forcing not to install"
            apt-get -yqq autoremove 

            juju-log "Installing common dependencies"
            # latest kernel doesn't have image-extra so we try only
            apt-get install -yqq  linux-image-extra-`uname -r` \
                || juju-log "linux-image-extra-`uname -r` not available. Skipping"

            # Installing driver only on bare metal
            [ "${LXC_CMD}" = "0" ] && \
                ${UBUNTU_CODENAME}::${ARCH}::install_nvidia_driver && \
                    juju-reboot || \
                    juju-log "Running in a container. No need for the nVidia Driver"
        ;;
    esac

    ${UBUNTU_CODENAME}::${ARCH}::install_openblas
    ${UBUNTU_CODENAME}::${ARCH}::install_cuda
    all::all::add_cuda_path

    status-set waiting "Waiting for reboot"
    charms.reactive set_state 'cuda.installed'
}

@when 'cuda.installed'
@when_not 'cuda.available'
function reboot() {

    status-set active "CUDA installed and available"
    charms.reactive set_state 'cuda.available'
}

reactive_handler_main
