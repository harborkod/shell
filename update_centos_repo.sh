#!/bin/bash

# 更新 CentOS 软件源为阿里云镜像
update_centos_repo() {
    echo "Updating CentOS repositories to Aliyun mirrors..."
    
    # 先修复 yum
    if [ -f ./fix_yum_direct.sh ]; then
        echo "Fixing yum first..."
        bash ./fix_yum_direct.sh
    fi
    
    # 备份原有的 repo 文件
    sudo mkdir -p /etc/yum.repos.d/backup
    sudo mv /etc/yum.repos.d/*.repo /etc/yum.repos.d/backup/ 2>/dev/null
    
    # 下载新的 repo 文件
    curl -o /etc/yum.repos.d/CentOS-Base.repo https://mirrors.aliyun.com/repo/Centos-7.repo
    if [ $? -ne 0 ]; then
        echo "Error: Failed to download CentOS-Base.repo"
        return 1
    fi
    
    # 添加 EPEL 源
    curl -o /etc/yum.repos.d/epel.repo https://mirrors.aliyun.com/repo/epel-7.repo
    if [ $? -ne 0 ]; then
        echo "Error: Failed to download epel.repo"
        return 1
    fi

    # 清除缓存并更新
    echo "Cleaning and updating yum cache..."
    yum clean all
    rm -rf /var/cache/yum/*
    yum makecache

    # 验证源是否可用
    if ! yum repolist | grep -E "base|extras|updates|epel" > /dev/null; then
        echo "Error: Repository verification failed"
        return 1
    fi

    echo "CentOS repositories have been updated to Aliyun mirrors successfully!"
    return 0
}

# 检查是否为 root 用户
if [[ $EUID -ne 0 ]]; then
    if ! command -v sudo &> /dev/null; then
        echo "This script requires sudo privileges. Please install sudo or run as root."
        exit 1
    fi
fi

# 执行更新
update_centos_repo 
exit $?
