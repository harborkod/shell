#!/bin/bash

# Nacos 版本和安装目录
NACOS_VERSION="2.3.2"  # 默认安装版本 2.3.2
INSTALL_DIR="/usr/local/nacos-$NACOS_VERSION"
DOWNLOAD_DIR="/opt"  # 下载目录
SRC_DIR="/usr/local/nacos-$NACOS_VERSION-src"  # 源代码解压目录
LOG_FILE="/tmp/nacos_install_$(date +%F_%T).log"

# 开始安装提示
echo "-----------------------------开始 Nacos 安装--------------------------------------"
start_time=$(date +%s)

# 确保有 sudo 权限
if [ "$EUID" -ne 0 ]; then
    echo "错误：此脚本需要 root 权限，请以 root 用户运行。"
    exit 1
fi

# Nacos 版本选择
select_nacos_version() {
    echo "请选择要安装的 Nacos 版本："
    echo "1) Nacos 2.3.2"
    echo "2) Nacos 2.1.2"
    read -p "请输入选项 [1-2]: " nacos_version_choice

    case $nacos_version_choice in
        1)
            NACOS_VERSION="2.3.2"
            NACOS_SOURCE_URL="https://download.nacos.io/nacos-server/nacos-server-2.3.2.zip"
            ;;
        2)
            NACOS_VERSION="2.1.2"
            NACOS_SOURCE_URL="https://github.com/alibaba/nacos/releases/download/2.1.2/nacos-server-2.1.2.zip"
            ;;
        *)
            echo "无效的选择，请重新运行脚本并选择正确的 Nacos 版本。"
            exit 1
            ;;
    esac
    INSTALL_DIR="/usr/local/nacos-$NACOS_VERSION"
    SRC_DIR="/usr/local/nacos-$NACOS_VERSION-src"
    echo "您选择安装 Nacos $NACOS_VERSION"
}

# 检查磁盘空间
check_disk_space() {
    AVAILABLE_SPACE=$(df /usr/local | tail -1 | awk '{print $4}')
    if [ "$AVAILABLE_SPACE" -lt 1000000 ]; then
        echo "错误：磁盘空间不足，至少需要 1GB 可用空间。" | tee -a $LOG_FILE
        exit 1
    fi
}

# 检查端口是否被占用
check_port_usage() {
    PORT=$1
    if lsof -i :$PORT >/dev/null; then
        echo "错误：端口 $PORT 已被占用，请释放该端口后再尝试安装。" | tee -a $LOG_FILE
        exit 1
    fi
}

# Nacos 端口检测
check_ports() {
    echo "-----------------------------检查 Nacos 所需端口--------------------------------------" | tee -a $LOG_FILE
    check_port_usage 8848  # HTTP 端口
    check_port_usage 9848  # gRPC 通信端口
    check_port_usage 9849  # Raft 选举端口
    check_port_usage 7848  # 集群通信端口

    echo "所有 Nacos 所需端口均未被占用，继续安装。" | tee -a $LOG_FILE
}

# 检测并停止正在运行的 Nacos 进程，并清理数据和安装目录
terminate_existing_nacos() {
    echo "检测是否有正在运行的 Nacos 进程..." | tee -a $LOG_FILE

    # 获取当前脚本的 PID
    CURRENT_PID=$$

    # 获取所有与 Nacos 相关的进程 (nacos-server)
    NACOS_PIDS=$(pgrep -f "nacos-server")

    if [ -n "$NACOS_PIDS" ]; then
        echo "检测到正在运行的 Nacos 进程，准备终止..." | tee -a $LOG_FILE
        echo "要终止的 Nacos 进程 PIDs: $NACOS_PIDS" | tee -a $LOG_FILE

        # 杀掉 Nacos 进程，跳过当前脚本的进程 ID
        for PID in $NACOS_PIDS; do
            if [ "$PID" -ne "$CURRENT_PID" ]; then
                kill -9 $PID
                if [ $? -eq 0 ]; then
                    echo "成功终止 Nacos 进程 PID: $PID" | tee -a $LOG_FILE
                else
                    echo "错误：无法终止 Nacos 进程 PID: $PID" | tee -a $LOG_FILE
                    exit 1
                fi
            else
                echo "跳过当前脚本的进程 PID: $PID" | tee -a $LOG_FILE
            fi
        done
    else
        echo "未发现正在运行的 Nacos 进程。" | tee -a $LOG_FILE
    fi

    # 删除旧的 Nacos 安装目录
    if [ -d "$INSTALL_DIR" ]; then
        echo "删除旧的 Nacos 安装目录..." | tee -a $LOG_FILE
        rm -rf $INSTALL_DIR
        if [ $? -eq 0 ]; then
            echo "成功删除 Nacos 安装目录。" | tee -a $LOG_FILE
        else
            echo "错误：无法删除 Nacos 安装目录。" | tee -a $LOG_FILE
            exit 1
        fi
    fi

    # 删除旧的 Nacos 源代码目录
    if [ -d "$SRC_DIR" ]; then
        echo "删除旧的 Nacos 源代码目录..." | tee -a $LOG_FILE
        rm -rf $SRC_DIR
        if [ $? -eq 0 ]; then
            echo "成功删除 Nacos 源代码目录。" | tee -a $LOG_FILE
        else
            echo "错误：无法删除 Nacos 源代码目录。" | tee -a $LOG_FILE
            exit 1
        fi
    fi
}


# 下载并解压 Nacos 源码
download_and_extract_nacos() {
    cd $DOWNLOAD_DIR

    # 如果文件已存在，验证文件的大小以确定是否已经下载完成
    if [ -f "nacos-server-$NACOS_VERSION.zip" ]; then
        echo "Nacos 源码包已存在，检查文件完整性..." | tee -a $LOG_FILE
        FILE_SIZE=$(stat -c%s "nacos-server-$NACOS_VERSION.zip")

        # 假设 100MB 为合理的文件大小标准
        if [ "$FILE_SIZE" -lt 100000000 ]; then
            echo "文件不完整，重新下载..." | tee -a $LOG_FILE
            rm "nacos-server-$NACOS_VERSION.zip"
        else
            echo "Nacos 源码包文件完整，跳过下载。" | tee -a $LOG_FILE
            return
        fi
    fi

    # 使用断点续传和超时设置下载 Nacos 源码包
    wget -c --tries=3 --timeout=30 --show-progress -O nacos-server-$NACOS_VERSION.zip $NACOS_SOURCE_URL 2>> $LOG_FILE
    if [ $? -ne 0 ]; then
        echo "错误：下载 Nacos 源码包失败。" | tee -a $LOG_FILE
        exit 1
    fi

    echo "解压 Nacos 源码包..." | tee -a $LOG_FILE
    unzip nacos-server-$NACOS_VERSION.zip -d /usr/local >> $LOG_FILE 2>&1
    mv /usr/local/nacos /usr/local/nacos-$NACOS_VERSION-src
}

# 创建 Nacos 用户和组
create_nacos_user() {
    if ! id -u nacos >/dev/null 2>&1; then
        groupadd nacos
        if [ $? -ne 0 ]; then
            echo "错误：无法创建 nacos 组。" | tee -a $LOG_FILE
            exit 1
        fi
        useradd -r -g nacos nacos
        if [ $? -ne 0 ]; then
            echo "错误：无法创建 nacos 用户。" | tee -a $LOG_FILE
            exit 1
        fi
    else
        echo "Nacos 用户已存在，跳过创建。" | tee -a $LOG_FILE
    fi
}

# 配置 Nacos
configure_nacos() {
    echo "-----------------------------配置 Nacos--------------------------------------" | tee -a $LOG_FILE
    cp -r $SRC_DIR/conf $INSTALL_DIR
    chown -R nacos:nacos $INSTALL_DIR

    # 配置 Nacos 的端口信息
    sed -i 's/^server.port=.*/server.port=8848/' $INSTALL_DIR/conf/application.properties
    echo "Nacos HTTP 端口已配置为 8848" | tee -a $LOG_FILE

    # 添加 gRPC 通信端口配置
    echo "grpc.port=9848" >> $INSTALL_DIR/conf/application.properties
    echo "Nacos gRPC 通信端口已配置为 9848" | tee -a $LOG_FILE

    # 添加 Raft 选举端口配置
    echo "raft.port=9849" >> $INSTALL_DIR/conf/application.properties
    echo "Nacos Raft 选举端口已配置为 9849" | tee -a $LOG_FILE

    # 配置集群通信端口（如果需要集群模式）
    echo "cluster.port=7848" >> $INSTALL_DIR/conf/application.properties
    echo "Nacos 集群通信端口已配置为 7848" | tee -a $LOG_FILE

    # 配置 Nacos 为后台运行
    echo "修改 Nacos 运行模式为后台..." | tee -a $LOG_FILE
    sed -i 's/^#.*nacos.isStandalone.*/nacos.isStandalone=true/' $INSTALL_DIR/conf/application.properties
}

# 启动 Nacos
start_nacos() {
    echo "-----------------------------启动 Nacos 服务--------------------------------------" | tee -a $LOG_FILE
    su -c "$SRC_DIR/bin/startup.sh -m standalone" nacos >> $LOG_FILE 2>&1
    if [ $? -ne 0 ]; then
        echo "错误：Nacos 启动失败，请检查日志 $LOG_FILE。" | tee -a $LOG_FILE
        exit 1
    fi
    if pgrep -f "nacos" > /dev/null; then
        echo "Nacos 服务已启动成功。" | tee -a $LOG_FILE
    else
        echo "错误：Nacos 服务未能启动，请检查日志。" | tee -a $LOG_FILE
        exit 1
    fi
}

# 检查并开放端口
open_port_if_not_open() {
    PORT=$1
    if firewall-cmd --zone=public --query-port=$PORT/tcp >/dev/null; then
        echo "端口 $PORT 已经开放，跳过此端口配置。" | tee -a $LOG_FILE
    else
        echo "端口 $PORT 尚未开放，正在开放..." | tee -a $LOG_FILE
        firewall-cmd --zone=public --add-port=$PORT/tcp --permanent
        if [ $? -eq 0 ]; then
            echo "端口 $PORT 成功开放。" | tee -a $LOG_FILE
        else
            echo "错误：无法开放端口 $PORT。" | tee -a $LOG_FILE
        fi
    fi
}

# 设置防火墙规则开放 Nacos 所需端口
configure_firewall() {
    if systemctl is-active --quiet firewalld; then
        echo "防火墙已启用，检查并配置 Nacos 所需端口开放规则..." | tee -a $LOG_FILE

        # 检查并开放 Nacos HTTP 端口 8848
        open_port_if_not_open 8848

        # 检查并开放 Nacos gRPC 通信端口 9848
        open_port_if_not_open 9848

        # 检查并开放 Nacos Raft 选举端口 9849
        open_port_if_not_open 9849

        # 检查并开放 Nacos 集群通信端口 7848
        open_port_if_not_open 7848

        # 重新加载防火墙配置以使规则生效
        firewall-cmd --reload
        echo "防火墙规则已重新加载，Nacos 端口规则已生效。" | tee -a $LOG_FILE
    else
        echo "警告：firewalld 未运行，请手动开放端口或使用其他防火墙工具。" | tee -a $LOG_FILE
    fi
}

# 设置环境变量
configure_environment_variables() {
    ENV_FILE="/etc/profile.d/nacos_env.sh"
    
    # 如果环境变量文件已存在，先备份
    if [ -f "$ENV_FILE" ];then
        BACKUP_FILE="/etc/profile.d/nacos_env.sh.bak_$(date +%F_%T)"
        echo "检测到已有 Nacos 环境变量文件，正在备份为 $BACKUP_FILE" | tee -a $LOG_FILE
        mv $ENV_FILE $BACKUP_FILE
    fi

    # 设置 Nacos 的 PATH 变量
    cat <<EOF > $ENV_FILE
export PATH=\$PATH:$INSTALL_DIR/bin
EOF

    # 加载环境变量
    source $ENV_FILE
    echo "Nacos 环境变量已设置并加载成功" | tee -a $LOG_FILE
}

# 验证 Nacos 安装
validate_nacos_installation() {
    if pgrep -f "nacos" > /dev/null; then
        echo "Nacos 服务正在运行" | tee -a $LOG_FILE
    else
        echo "错误：Nacos 服务未能启动，请检查日志" | tee -a $LOG_FILE
        exit 1
    fi
}

# 打印 Nacos 服务管理提示
print_nacos_service_info() {
    echo "-----------------------------Nacos 服务管理信息--------------------------------------" | tee -a $LOG_FILE
    echo "Nacos $NACOS_VERSION 已成功安装并启动。" | tee -a $LOG_FILE
    echo ""
    echo "请先执行以下命令加载环境变量：" | tee -a $LOG_FILE
    echo "source /etc/profile.d/nacos_env.sh" | tee -a $LOG_FILE
    echo ""
    echo "Nacos 服务管理命令：" | tee -a $LOG_FILE
    echo "启动服务: $SRC_DIR/bin/startup.sh" | tee -a $LOG_FILE
    echo "停止服务: $SRC_DIR/bin/shutdown.sh" | tee -a $LOG_FILE
}

# 主函数
main() {
    select_nacos_version
    check_disk_space
    check_ports              # 添加端口占用检查
    terminate_existing_nacos   # 检测并终止 Nacos 进程，清理旧的安装和数据
    download_and_extract_nacos
    check_extracted_files
    create_nacos_user
    configure_nacos    # 配置 Nacos
    start_nacos
    configure_firewall        # 开放 Nacos 所需端口
    configure_environment_variables
    validate_nacos_installation
    print_nacos_service_info
}

# 执行主程序
main
