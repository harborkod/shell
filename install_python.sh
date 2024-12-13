#!/bin/bash

PYTHON_VERSION="3.12.0"
PYTHON_DOWNLOAD_URL="https://harborkod.oss-rg-china-mainland.aliyuncs.com/arch/python/Python-${PYTHON_VERSION}.tgz"
INSTALL_DIR="/usr/local"
TEMP_DIR="$HOME/python_install"

# 检查是否为 root 用户
check_root() {
    if [[ $EUID -ne 0 ]]; then
        if ! command -v sudo &> /dev/null; then
            echo "This script requires sudo privileges. Please install sudo or run as root."
            exit 1
        fi
    fi
}

# 检查并处理已存在的 Python 安装
check_existing_installation() {
    if command -v python3.12 &> /dev/null; then
        echo "Python 3.12 is already installed."
        echo "Current version:"
        python3.12 --version
        
        read -p "Do you want to remove it and reinstall? (y/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Installation cancelled."
            exit 1
        fi
        
        remove_old_installation
    fi
}

# 移除旧的 Python 安装
remove_old_installation() {
    echo "Removing old Python 3.12 installation..."
    sudo rm -f ${INSTALL_DIR}/bin/python3.12
    sudo rm -f ${INSTALL_DIR}/bin/pip3.12
    sudo rm -f ${INSTALL_DIR}/bin/python3
    sudo rm -f ${INSTALL_DIR}/bin/pip3
    sudo rm -rf ${INSTALL_DIR}/lib/python3.12
    sudo rm -f /etc/ld.so.conf.d/python3.12.conf
    sudo ldconfig
}

# 安装依赖包
install_dependencies() {
    echo "Installing dependencies..."
    sudo yum groupinstall -y "Development Tools"
    sudo yum install -y \
        openssl-devel \
        bzip2-devel \
        libffi-devel \
        zlib-devel \
        readline-devel \
        sqlite-devel \
        tk-devel \
        xz-devel \
        wget
}

# 准备安装目录
prepare_installation_directory() {
    echo "Preparing installation directory..."
    if [ -d "$TEMP_DIR" ]; then
        rm -rf "$TEMP_DIR"
    fi
    mkdir -p "$TEMP_DIR"
}

# 下载和解压 Python 源码
download_and_extract() {
    echo "Downloading Python ${PYTHON_VERSION}..."
    cd "$TEMP_DIR"
    wget "$PYTHON_DOWNLOAD_URL"
    
    echo "Extracting Python source..."
    tar xzf "Python-${PYTHON_VERSION}.tgz"
    cd "Python-${PYTHON_VERSION}"
}

# 配置和编译 Python
configure_and_build() {
    echo "Configuring Python..."
    ./configure --enable-optimizations \
        --with-ensurepip=install \
        --enable-shared \
        --prefix=${INSTALL_DIR}

    echo "Compiling and installing Python..."
    make -j $(nproc)
    sudo make altinstall
}

# 配置系统链接和路径
configure_system() {
    echo "Creating symbolic links..."
    sudo ln -sf ${INSTALL_DIR}/bin/python3.12 ${INSTALL_DIR}/bin/python3
    sudo ln -sf ${INSTALL_DIR}/bin/pip3.12 ${INSTALL_DIR}/bin/pip3

    echo "Configuring dynamic linker..."
    echo "${INSTALL_DIR}/lib" | sudo tee /etc/ld.so.conf.d/python3.12.conf
    sudo ldconfig
}

# 清理安装文件
cleanup() {
    echo "Cleaning up..."
    cd "$HOME"
    rm -rf "$TEMP_DIR"
}

# 验证安装
verify_installation() {
    echo "Verifying installation..."
    if python3 --version && pip3 --version; then
        echo "Python ${PYTHON_VERSION} installation completed successfully!"
        return 0
    else
        echo "Installation verification failed!"
        return 1
    fi
}

# 主函数
main() {
    echo "Starting Python ${PYTHON_VERSION} installation..."
    
    check_root
    check_existing_installation
    install_dependencies
    prepare_installation_directory
    download_and_extract
    configure_and_build
    configure_system
    cleanup
    verify_installation
}

# 捕获错误
set -e
trap 'echo "Error occurred. Installation failed!"; exit 1' ERR

# 执行主函数
main 
