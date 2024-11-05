#!/bin/bash

# Nexus 版本和安装目录
NEXUS_VERSION="3.69.0-02"  # 默认安装版本
INSTALL_DIR="/usr/local/nexus-$NEXUS_VERSION"
DOWNLOAD_DIR="/opt"  # 下载目录
NEXUS_SOURCE_URL="https://harborkod.oss-rg-china-mainland.aliyuncs.com/arch/nexus/nexus-3.69.0-02-java17-unix.tar.gz"  # Nexus 下载链接
LOG_FILE="/tmp/nexus_install_$(date +%F_%T).log"

# 开始安装提示
echo "-----------------------------开始 Nexus 安装--------------------------------------"
start_time=$(date +%s)

# 确保有 sudo 权限
if [ "$EUID" -ne 0 ]; then
    echo "错误：此脚本需要 root 权限，请以 root 用户运行。"
    exit 1
fi

# 检查磁盘空间
check_disk_space() {
    AVAILABLE_SPACE=$(df /usr/local | tail -1 | awk '{print $4}')
    if [ "$AVAILABLE_SPACE" -lt 1000000 ]; then
        echo "错误：磁盘空间不足，至少需要 1GB 可用空间。" | tee -a $LOG_FILE
        exit 1
    fi
}

# 检查并终止正在运行的 Nexus 进程
terminate_existing_nexus() {
    echo "检测是否有正在运行的 Nexus 进程..." | tee -a $LOG_FILE
    NEXUS_PIDS=$(pgrep -f "nexus")

    # 获取当前脚本的 PID
    CURRENT_PID=$$

    if [ -n "$NEXUS_PIDS" ]; then
        echo "检测到正在运行的 Nexus 进程，准备终止..." | tee -a $LOG_FILE
        for PID in $NEXUS_PIDS; do
            # 确保不杀掉当前脚本进程
            if [ "$PID" -ne "$CURRENT_PID" ]; then
                kill -9 $PID
                echo "成功终止 Nexus 进程 PID: $PID" | tee -a $LOG_FILE
            else
                echo "跳过当前脚本进程 PID: $PID" | tee -a $LOG_FILE
            fi
        done
    else
        echo "未发现正在运行的 Nexus 进程。" | tee -a $LOG_FILE
    fi
}

# 下载并解压 Nexus
download_and_extract_nexus() {
    echo "下载 Nexus 源码包..." | tee -a $LOG_FILE
    cd $DOWNLOAD_DIR
    wget -O nexus-$NEXUS_VERSION.tar.gz $NEXUS_SOURCE_URL
    if [ $? -ne 0 ]; then
        echo "错误：下载 Nexus 源码包失败。" | tee -a $LOG_FILE
        exit 1
    fi

    echo "解压 Nexus 源码包..." | tee -a $LOG_FILE
    tar -zxvf nexus-$NEXUS_VERSION.tar.gz -C /usr/local
}

# 创建 Nexus 用户和组
create_nexus_user() {
    if ! id -u nexus >/dev/null 2>&1; then
        groupadd nexus
        useradd -r -g nexus nexus
        echo "Nexus 用户和组已创建。" | tee -a $LOG_FILE
    else
        echo "Nexus 用户已存在，跳过创建。" | tee -a $LOG_FILE
    fi
}

# 配置 Nexus
configure_nexus() {
    echo "配置 Nexus..." | tee -a $LOG_FILE
    mv /usr/local/nexus-$NEXUS_VERSION /usr/local/nexus
    chown -R nexus:nexus /usr/local/nexus

    # 创建 sonatype-work 目录并设置权限
    SONATYPE_WORK_DIR="/usr/local/sonatype-work"
    if [ ! -d "$SONATYPE_WORK_DIR" ]; then
        mkdir -p "$SONATYPE_WORK_DIR"
        echo "创建 sonatype-work 目录..." | tee -a $LOG_FILE
    fi
    chown -R nexus:nexus "$SONATYPE_WORK_DIR"  # 设置 sonatype-work 目录的权限
}

# 配置开机自启动
configure_autostart() {
    echo "配置 Nexus 开机自启动服务..." | tee -a $LOG_FILE
    cat <<EOF > /etc/systemd/system/nexus.service
[Unit]
Description=Nexus Repository Manager
After=network.target

[Service]
Type=simple
User=nexus
Group=nexus
ExecStart=/usr/local/nexus/bin/nexus start
ExecStop=/usr/local/nexus/bin/nexus stop
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

    # 重新加载 systemd 配置
    systemctl daemon-reload
    # 启用 Nexus 服务开机自启动
    systemctl enable nexus
    echo "Nexus 开机自启动服务已配置。" | tee -a $LOG_FILE
}

# 启动 Nexus
start_nexus() {
    echo "启动 Nexus 服务..." | tee -a $LOG_FILE
    systemctl start nexus
    if systemctl is-active --quiet nexus; then
        echo "Nexus 服务已成功启动。" | tee -a $LOG_FILE
    else
        echo "错误：Nexus 服务未能启动，请检查日志。" | tee -a $LOG_FILE
        exit 1
    fi
}

# 主函数
main() {
    check_disk_space
    terminate_existing_nexus
    download_and_extract_nexus
    create_nexus_user
    configure_nexus
    configure_autostart  # 配置开机自启动
    start_nexus          # 启动 Nexus
}

# 执行主程序
main