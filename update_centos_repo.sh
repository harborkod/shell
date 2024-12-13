#!/bin/bash

# 更新 CentOS 软件源为阿里云镜像
update_centos_repo() {
    echo "Updating CentOS repositories to Aliyun mirrors..."
    
    # 备份原有的 repo 文件
    sudo mkdir -p /etc/yum.repos.d/backup
    sudo mv /etc/yum.repos.d/*.repo /etc/yum.repos.d/backup/
    
    # 添加阿里云镜像源
    sudo tee /etc/yum.repos.d/CentOS-Base.repo << 'EOF'
[base]
name=CentOS-$releasever - Base - mirrors.aliyun.com
failovermethod=priority
baseurl=http://mirrors.aliyun.com/centos/$releasever/os/$basearch/
gpgcheck=1
gpgkey=http://mirrors.aliyun.com/centos/RPM-GPG-KEY-CentOS-7

[updates]
name=CentOS-$releasever - Updates - mirrors.aliyun.com
failovermethod=priority
baseurl=http://mirrors.aliyun.com/centos/$releasever/updates/$basearch/
gpgcheck=1
gpgkey=http://mirrors.aliyun.com/centos/RPM-GPG-KEY-CentOS-7

[extras]
name=CentOS-$releasever - Extras - mirrors.aliyun.com
failovermethod=priority
baseurl=http://mirrors.aliyun.com/centos/$releasever/extras/$basearch/
gpgcheck=1
gpgkey=http://mirrors.aliyun.com/centos/RPM-GPG-KEY-CentOS-7
EOF

    # 添加 EPEL 源
    sudo yum install -y epel-release
    sudo sed -i 's|^#baseurl=http://download.fedoraproject.org/pub|baseurl=http://mirrors.aliyun.com|' /etc/yum.repos.d/epel.repo
    sudo sed -i 's|^metalink|#metalink|' /etc/yum.repos.d/epel.repo

    # 清除缓存并更新
    echo "Cleaning and updating yum cache..."
    sudo yum clean all
    sudo yum makecache

    echo "CentOS repositories have been updated to Aliyun mirrors successfully!"
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
