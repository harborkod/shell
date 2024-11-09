#!/bin/bash

# Nexus 版本和安装目录
NEXUS_VERSION="3.72.0-04"  # 默认安装版本
INSTALL_DIR="/usr/local/nexus-$NEXUS_VERSION"
DOWNLOAD_DIR="/opt"  # 下载目录
NEXUS_SOURCE_URL="https://harborkod.oss-rg-china-mainland.aliyuncs.com/arch/nexus/nexus-3.72.0-04-unix.tar.gz"  # Nexus 下载链接
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

# 删除旧的 Nexus 数据
cleanup_old_nexus() {
    echo "清理旧的 Nexus 数据..." | tee -a $LOG_FILE

    # 删除旧的 Nexus 源码包
    if [ -f "$DOWNLOAD_DIR/nexus-$NEXUS_VERSION.tar.gz" ]; then
        echo "删除旧的 Nexus 源码包..." | tee -a $LOG_FILE
        rm -f "$DOWNLOAD_DIR/nexus-$NEXUS_VERSION.tar.gz"
    fi

    # 删除旧的 Nexus 解压目录
    if [ -d "/usr/local/nexus-$NEXUS_VERSION" ]; then
        echo "删除旧的 Nexus 解压目录..." | tee -a $LOG_FILE
        rm -rf "/usr/local/nexus-$NEXUS_VERSION"
    fi

    # 删除 sonatype-work 目录
    SONATYPE_WORK_DIR="/usr/local/sonatype-work"
    if [ -d "$SONATYPE_WORK_DIR" ]; then
        echo "删除旧的 sonatype-work 目录..." | tee -a $LOG_FILE
        rm -rf "$SONATYPE_WORK_DIR"
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

# 配置 Nexus
configure_nexus() {
    echo "配置 Nexus..." | tee -a $LOG_FILE

    # 检查 Nexus 目录是否存在
    if [ ! -d "/usr/local/nexus-$NEXUS_VERSION" ]; then
        echo "错误：Nexus 目录 /usr/local/nexus-$NEXUS_VERSION 不存在，无法设置权限。" | tee -a $LOG_FILE
        exit 1
    fi

    # 检查 sonatype-work 目录是否存在
    SONATYPE_WORK_DIR="/usr/local/sonatype-work"
    if [ ! -d "$SONATYPE_WORK_DIR" ]; then
        echo "错误：sonatype-work 目录 $SONATYPE_WORK_DIR 不存在，无法设置权限。" | tee -a $LOG_FILE
        exit 1
    fi

    chown -R nexus:nexus /usr/local/nexus-$NEXUS_VERSION  # 设置 Nexus 目录的权限
    chown -R nexus:nexus "$SONATYPE_WORK_DIR"  # 设置 sonatype-work 目录的权限
}

# 创建 Nexus 用户和组
create_nexus_user() {
    # 检查主目录是否存在
    if [ ! -d "/usr/local/nexus-$NEXUS_VERSION" ]; then
        echo "错误：指定的 home 目录 /usr/local/nexus-$NEXUS_VERSION 不存在，无法创建用户。" | tee -a $LOG_FILE
        exit 1
    fi

    if ! id -u nexus >/dev/null 2>&1; then
        groupadd nexus
        useradd -r -g nexus -d /usr/local/nexus-$NEXUS_VERSION nexus  # 指定 home dir 为移动后的 nexus 目录
        echo "Nexus 用户和组已创建。" | tee -a $LOG_FILE
    else
        echo "Nexus 用户已存在，跳过创建。" | tee -a $LOG_FILE
    fi
}

# 设置 Nexus 环境变量并刷新
setup_nexus_env() {
    echo "设置 Nexus 环境变量..." | tee -a $LOG_FILE
    echo "export NEXUS_HOME=/usr/local/nexus-$NEXUS_VERSION" >> /etc/profile.d/nexus.sh
    echo "export PATH=\$PATH:\$NEXUS_HOME/bin" >> /etc/profile.d/nexus.sh
    source /etc/profile.d/nexus.sh  # 刷新环境变量
}

# 修改 nexus.rc 文件并检查可用内存
configure_nexus_rc_and_memory() {
    # 修改 nexus.rc 文件
    NEXUS_RC_FILE="/usr/local/nexus-$NEXUS_VERSION/bin/nexus.rc"
    
    # 清空文件内容并写入新的内容
    echo 'run_as_user="nexus"' > "$NEXUS_RC_FILE"

    # 检查可用内存
    AVAILABLE_MEMORY=$(free -m | awk '/^Mem:/{print $7}')
    echo "当前可用内存为 ${AVAILABLE_MEMORY}MB。" | tee -a $LOG_FILE

    # 根据可用内存设置 -Xms 和 -Xmx
    if [ "$AVAILABLE_MEMORY" -lt 615 ]; then
        echo "错误：可用内存不足，当前可用内存为 ${AVAILABLE_MEMORY}MB，最低要求为 615MB。" | tee -a $LOG_FILE
        exit 1
    elif [ "$AVAILABLE_MEMORY" -ge 615 ] && [ "$AVAILABLE_MEMORY" -le 1229 ]; then
        XMS=512
        XMX=512
    elif [ "$AVAILABLE_MEMORY" -ge 1230 ] && [ "$AVAILABLE_MEMORY" -le 2458 ]; then
        XMS=1024
        XMX=1024
    else
        XMS=2048
        XMX=2048
    fi

    # 配置 nexus.vmoptions 文件
    NEXUS_VM_OPTIONS_FILE="/usr/local/nexus-$NEXUS_VERSION/bin/nexus.vmoptions"
    sed -i "s/-Xms.*$/-Xms${XMS}m/" "$NEXUS_VM_OPTIONS_FILE"  # 设置初始堆大小
    sed -i "s/-Xmx.*$/-Xmx${XMX}m/" "$NEXUS_VM_OPTIONS_FILE"  # 设置最大堆大小

    echo "已设置 -Xms 和 -Xmx 为 ${XMS}MB。" | tee -a $LOG_FILE
}

# 配置开机自启动
configure_autostart() {
    echo "配置 Nexus 开机自启动服务..." | tee -a $LOG_FILE
    cat <<EOF > /etc/systemd/system/nexus.service
[Unit]
Description=Nexus Repository Manager
After=network.target

[Service]
Type=forking
User=nexus
Group=nexus
ExecStart=/usr/local/nexus-$NEXUS_VERSION/bin/nexus start
ExecStop=/usr/local/nexus-$NEXUS_VERSION/bin/nexus stop
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
    setup_nexus_env  # 设置环境变量
    configure_nexus_rc_and_memory  # 修改 nexus.rc 文件并检查可用内存
    configure_autostart  # 配置开机自启动
    start_nexus          # 启动 Nexus
}

# 执行主程序
main
