#!/bin/bash

# Redis 版本和安装目录
REDIS_VERSION="6.2.9"  # 默认安装版本 6.2.9
REDIS_PASSWORD="harborKod@redis@root" # Redis 全局密码
INSTALL_DIR="/usr/local/redis-$REDIS_VERSION"
DATA_DIR="$INSTALL_DIR/data"  # Redis 数据目录
LOG_DIR="$INSTALL_DIR/log"    # Redis 日志目录
DOWNLOAD_DIR="/opt"           # 下载目录
SRC_DIR="/usr/local/redis-$REDIS_VERSION-src"  # 源代码解压目录

# 开始安装提示
echo "-----------------------------开始 Redis 安装--------------------------------------"
start_time=$(date +%s)

# 确保有 sudo 权限
if [ "$EUID" -ne 0 ]; then
    echo "错误：此脚本需要 root 权限，请以 root 用户运行。"
    exit 1
fi

# Redis 版本选择
select_redis_version() {
    echo "请选择要安装的 Redis 版本："
    echo "1) Redis 6.2.9"
    echo "2) Redis 7.0.8"
    read -p "请输入选项 [1-2]: " redis_version_choice

    case $redis_version_choice in
        1)
            REDIS_VERSION="6.2.9"
            REDIS_SOURCE_URL="https://mirrors.huaweicloud.com/redis/redis-6.2.9.tar.gz"
            ;;
        2)
            REDIS_VERSION="7.0.8"
            REDIS_SOURCE_URL="https://mirrors.huaweicloud.com/redis/redis-7.0.8.tar.gz"
            ;;
        *)
            echo "无效的选择，请重新运行脚本并选择正确的 Redis 版本。"
            exit 1
            ;;
    esac
    INSTALL_DIR="/usr/local/redis-$REDIS_VERSION"
    SRC_DIR="/usr/local/redis-$REDIS_VERSION-src"
    DATA_DIR="$INSTALL_DIR/data"
    LOG_DIR="$INSTALL_DIR/log"
    echo "您选择安装 Redis $REDIS_VERSION"
}

# 检查磁盘空间
check_disk_space() {
    AVAILABLE_SPACE=$(df /usr/local | tail -1 | awk '{print $4}')
    if [ "$AVAILABLE_SPACE" -lt 1000000 ]; then
        echo "错误：磁盘空间不足，至少需要 1GB 可用空间。"
        exit 1
    fi
}

# 检测并停止正在运行的 Redis 进程，并清理数据和安装目录
terminate_existing_redis() {
    # 检查端口 6379 是否被占用
    echo "检查是否有进程占用 6379 端口..."
    pid=$(lsof -t -i:6379)
    if [ -n "$pid" ]; then
        echo "检测到占用 6379 端口的进程 (PID: $pid)，准备终止..."
        kill -9 $pid
        if [ $? -eq 0 ]; then
            echo "已成功终止占用 6379 端口的进程。"
        else
            echo "错误：无法终止占用 6379 端口的进程。"
            exit 1
        fi
    else
        echo "未检测到占用 6379 端口的进程。"
    fi

    if pgrep -x "redis-server" > /dev/null; then
        echo "检测到正在运行的 Redis 进程，准备停止..."
        pkill redis-server
        if [ $? -eq 0 ]; then
            echo "Redis 进程已成功终止。"
        else
            echo "错误：无法终止 Redis 进程。"
            exit 1
        fi
    else
        echo "未发现正在运行的 Redis 进程。"
    fi

    # 删除旧的 Redis 安装目录
    if [ -d "$INSTALL_DIR" ]; then
        echo "删除旧的 Redis 安装目录..."
        rm -rf $INSTALL_DIR
        if [ $? -eq 0 ]; then
            echo "成功删除 Redis 安装目录。"
        else
            echo "错误：无法删除 Redis 安装目录。"
            exit 1
        fi
    fi

    # 删除旧的 Redis 源代码目录
    if [ -d "$SRC_DIR" ]; then
        echo "删除旧的 Redis 源代码目录..."
        rm -rf $SRC_DIR
        if [ $? -eq 0 ];then
            echo "成功删除 Redis 源代码目录。"
        else
            echo "错误：无法删除 Redis 源代码目录。"
            exit 1
        fi
    fi
}


# 下载并解压 Redis 源码
download_and_extract_redis() {
    cd $DOWNLOAD_DIR
    if [ -f "redis-$REDIS_VERSION.tar.gz" ]; then
        echo "Redis 源码包已存在，跳过下载。"
    else
        wget -O redis-$REDIS_VERSION.tar.gz $REDIS_SOURCE_URL
        if [ $? -ne 0 ]; then
            echo "错误：下载 Redis 源码包失败。"
            exit 1
        fi
    fi
    tar -zxvf redis-$REDIS_VERSION.tar.gz -C /usr/local
    mv /usr/local/redis-$REDIS_VERSION /usr/local/redis-$REDIS_VERSION-src
}

# 检查解压目录是否存在
check_extracted_files() {
    if [ ! -d "$SRC_DIR" ]; then
        echo "错误：解压 Redis 源码文件失败，请检查 tar 包是否完整。"
        exit 1
    fi
}

# 编译 Redis 源码
compile_redis() {
    echo "-----------------------------编译 Redis 源码--------------------------------------"
    cd $SRC_DIR
    make -j  # 使用并行编译
    if [ $? -ne 0 ]; then
        echo "错误：编译 Redis 源码失败。"
        exit 1
    fi
    make install PREFIX=$INSTALL_DIR NO_TEST=1 > /tmp/redis_install.log 2>&1  # 跳过测试并记录日志
    if [ $? -ne 0 ]; then
        echo "错误：Redis 安装失败，请检查 /tmp/redis_install.log"
        exit 1
    fi
    echo "Redis 安装成功，编译日志保存在 /tmp/redis_install.log"
}

# 创建 Redis 用户和组
create_redis_user() {
    if ! id -u redis >/dev/null 2>&1; then
        groupadd redis
        useradd -r -g redis redis
    fi
}

# 删除旧的 Redis 配置文件
remove_old_config() {
    if [ -f "/etc/redis.conf" ]; then
        mv /etc/redis.conf /etc/redis.conf.bak_$(date +%F_%T)
        echo "旧的 Redis 配置文件已备份为 /etc/redis.conf.bak_$(date +%F_%T)"
    fi
}

# 配置 Redis
configure_redis() {
    echo "-----------------------------配置 Redis--------------------------------------"
    
    cat <<EOF > /etc/redis.conf
# 网络相关配置
bind 0.0.0.0                   
port 6379                      
requirepass $REDIS_PASSWORD             
  
# 日志相关配置
loglevel notice                
logfile "$LOG_DIR/redis.log"   
databases 16                   

# 快照配置（RDB 持久化）
save 900 1                     
save 300 10                    
save 60 10000                  
dbfilename dump.rdb            
dir $DATA_DIR                  

# AOF 持久化配置
appendonly yes                 
appendfilename "appendonly.aof"
appendfsync everysec           

# 客户端连接相关配置
maxclients 100   
# 客户端连接超时时间，单位为秒
timeout 300             

# 保护模式配置
protected-mode no   

# 后台运行 Redis
daemonize yes             
          

EOF

    if [ $? -ne 0 ]; then
        echo "错误：Redis 配置文件写入失败。"
        exit 1
    fi

    # 验证配置文件是否正确写入
    if [ -f "/etc/redis.conf" ]; then
        echo "Redis 配置文件已成功写入：/etc/redis.conf"
    else
        echo "错误：Redis 配置文件写入失败，请检查文件路径和权限。"
        exit 1
    fi
}

# 创建必要的目录
create_directories() {
    echo "-----------------------------创建数据和日志目录--------------------------------------"
    mkdir -p $DATA_DIR $LOG_DIR
    chown -R redis:redis $DATA_DIR $LOG_DIR
    chmod -R 750 $DATA_DIR $LOG_DIR
    if [ $? -eq 0 ]; then
        echo "成功创建数据目录 $DATA_DIR 和日志目录 $LOG_DIR，并设置权限。"
    else
        echo "错误：无法创建目录或设置权限。"
        exit 1
    fi
}

# 启动 Redis
start_redis() {
    echo "-----------------------------启动 Redis 服务--------------------------------------"
    su -c "$INSTALL_DIR/bin/redis-server /etc/redis.conf" redis
    if pgrep -x "redis-server" >/dev/null; then
        echo "Redis 服务已启动成功。"
    else
        echo "Redis 服务启动失败，请检查日志。"
        exit 1
    fi
}

# 设置防火墙规则开放 6379 端口
configure_firewall() {
    if systemctl is-active --quiet firewalld; then
        echo "防火墙已启用，配置 6379 端口开放规则..."
        firewall-cmd --zone=public --add-port=6379/tcp --permanent
        firewall-cmd --reload
        echo "6379 端口已开放。"
    else
        echo "防火墙未启用，跳过端口配置。"
    fi
}

# 删除源代码目录
clean_source_directory() {
    echo "-----------------------------删除 Redis 源代码目录--------------------------------------"
    rm -rf $SRC_DIR
    if [ $? -ne 0 ]; then
        echo "错误：删除源代码目录失败。"
        exit 1
    fi
}

# 设置环境变量
configure_environment_variables() {
    ENV_FILE="/etc/profile.d/redis_env.sh"
    
    # 如果环境变量文件已存在，先备份
    if [ -f "$ENV_FILE" ];then
        BACKUP_FILE="/etc/profile.d/redis_env.sh.bak_$(date +%F_%T)"
        echo "检测到已有 Redis 环境变量文件，正在备份为 $BACKUP_FILE"
        mv $ENV_FILE $BACKUP_FILE
    fi

    # 设置 Redis 的 PATH 变量
    cat <<EOF > $ENV_FILE
export PATH=\$PATH:$INSTALL_DIR/bin
EOF

    # 加载环境变量
    source $ENV_FILE
    echo "Redis 环境变量已设置并加载成功"
}

# 验证 Redis 安装
validate_redis_installation() {
    if pgrep -x "redis-server" > /dev/null; then
        echo "Redis 服务正在运行"
    else
        echo "错误：Redis 服务未能启动，请检查日志"
        exit 1
    fi

    REDIS_VERSION_OUTPUT=$($INSTALL_DIR/bin/redis-server --version)
    if [[ "$REDIS_VERSION_OUTPUT" == *"$REDIS_VERSION"* ]]; then
        echo "Redis 安装成功，版本：$REDIS_VERSION_OUTPUT"
    else
        echo "错误：Redis 版本验证失败"
        exit 1
    fi
}


# 配置 Redis 开机自启动服务
configure_redis_autostart_service() {
    echo "-----------------------------配置 Redis 开机自启动服务--------------------------------------"

    cat <<EOF > /etc/systemd/system/redis.service
[Unit]
Description=Redis In-Memory Data Store
After=network.target

[Service]
Type=forking
User=redis
Group=redis
ExecStart=$INSTALL_DIR/bin/redis-server /etc/redis.conf
ExecStop=$INSTALL_DIR/bin/redis-cli -a $REDIS_PASSWORD shutdown
Restart=always

[Install]
WantedBy=multi-user.target
EOF

    # 重载 systemd 配置
    systemctl daemon-reload

    # 设置 Redis 服务为开机自启动
    systemctl enable redis

    # 检查是否成功设置为开机自启动
    if [ $? -eq 0 ]; then
        echo "Redis 已成功配置为开机自启动服务。"
    else
        echo "错误：配置 Redis 开机自启动失败。"
        exit 1
    fi
}



# 打印 Redis 服务管理提示
print_redis_service_info() {
    # 获取 Redis 进程 ID
    REDIS_PID=$(pgrep redis-server)

    echo "-----------------------------Redis 服务管理信息--------------------------------------"
    echo "Redis $REDIS_VERSION 已成功安装并启动。"
    echo "Redis 进程 ID: $REDIS_PID"
    echo "Redis root 密码: '$REDIS_PASSWORD'"
    echo ""
    echo "请先执行以下命令加载环境变量："
    echo "source /etc/profile.d/redis_env.sh"
    echo ""
    echo "Redis 服务管理命令："
    echo "启动服务: redis-server /etc/redis.conf"
    echo "停止服务: pkill redis-server"
    echo "查看 Redis 进程: pgrep redis-server"
    echo ""
    echo "Redis 客户端使用方法："
    echo "启动 Redis 客户端: redis-cli -a $REDIS_PASSWORD"
    echo "连接远程 Redis 服务器: redis-cli -h <remote_ip> -p 6379 -a $REDIS_PASSWORD"
}

# 主函数
main() {
    select_redis_version
    check_disk_space
    terminate_existing_redis   # 检测并终止 Redis 进程，清理旧的安装和数据
    download_and_extract_redis
    check_extracted_files
    compile_redis
    create_redis_user
    remove_old_config  # 删除旧配置
    configure_redis    # 配置新配置
    create_directories
    start_redis
    configure_firewall
    configure_environment_variables
    validate_redis_installation
    configure_redis_autostart_service  # 设置开机自启动
    print_redis_service_info
    clean_source_directory
}

# 执行主程序
main
