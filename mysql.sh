#!/bin/bash

# 设置 MySQL 版本和相关目录
MYSQL_VERSION="8.0.24" # 默认版本为8.0.24
BOOST_VERSION="1_59_0"
MYSQL_ROOT_PASSWORD="harborKod@mysql@root" # 全局变量设置 root 密码
BOOST_SOURCE_URL="https://sourceforge.net/projects/boost/files/boost/1.59.0/boost_1_59_0.tar.gz/download"
INSTALL_DIR="/usr/local/mysql-$MYSQL_VERSION" # MySQL 安装目录
DATA_DIR="$INSTALL_DIR/data" # MySQL 数据目录
BOOST_DIR="/usr/local/boost" # Boost 安装目录
BACKUP_DIR="/backup"
DOWNLOAD_DIR="/opt" # 所有下载的包放在 /opt 目录
SRC_DIR="/usr/local/mysql-$MYSQL_VERSION-src" # 源代码解压目录
LOG_DIR="$INSTALL_DIR/log" # 错误日志目录，放在安装目录下
BINLOG_DIR="$INSTALL_DIR/binlog" # 二进制日志目录，放在安装目录下
TMP_DIR="$INSTALL_DIR/tmp" # 临时文件目录，放在安装目录下

# 开始安装的提示信息
echo "-----------------------------开始 MySQL 安装--------------------------------------"
start_time=$(date +%s)

# 确保有 sudo 权限
if [ "$EUID" -ne 0 ]; then
    echo "错误：此脚本需要 root 权限，请以 root 用户运行。"
    exit 1
fi

# MySQL 版本选择
select_mysql_version() {
    echo "请选择要安装的 MySQL 版本："
    echo "1) MySQL 5.7.37"
    echo "2) MySQL 8.0.24"
    read -p "请输入选项 [1-2]: " mysql_version_choice

    case $mysql_version_choice in
        1)
            MYSQL_VERSION="5.7.37"
            MYSQL_SOURCE_URL="https://mirrors.huaweicloud.com/mysql/Downloads/MySQL-5.7/mysql-5.7.37.tar.gz"
            ;;
        2)
            MYSQL_VERSION="8.0.24"
            MYSQL_SOURCE_URL="https://mirrors.huaweicloud.com/mysql/Downloads/MySQL-8.0/mysql-8.0.24.tar.gz"
            ;;
        *)
            echo "无效的选择，请重新运行脚本并选择正确的 MySQL 版本。"
            exit 1
            ;;
    esac
    INSTALL_DIR="/usr/local/mysql-$MYSQL_VERSION"
    SRC_DIR="/usr/local/mysql-$MYSQL_VERSION-src" # 解压的源代码目录
    DATA_DIR="$INSTALL_DIR/data"
    LOG_DIR="$INSTALL_DIR/log"
    BINLOG_DIR="$INSTALL_DIR/binlog"
    TMP_DIR="$INSTALL_DIR/tmp"
    PID_FILE="$DATA_DIR/mysql.pid"
    echo "您选择安装 MySQL $MYSQL_VERSION"
}

# 检查是否有足够磁盘空间（前置校验）
check_disk_space() {
    AVAILABLE_SPACE=$(df /usr/local | tail -1 | awk '{print $4}')
    if [ "$AVAILABLE_SPACE" -lt 5000000 ]; then
        echo "错误：磁盘空间不足，至少需要 5GB 可用空间。"
        exit 1
    fi
}

# 检查并终止正在运行的 MySQL 进程，并清理旧的历史数据和安装包
terminate_existing_mysql() {
    echo "-----------------------------检查并终止正在运行的 MySQL 进程，清理历史数据和旧安装包--------------------------------------"
    mysql_pid=$(pgrep -x mysqld)
    
    if [ -n "$mysql_pid" ]; then
        echo "发现正在运行的 MySQL 进程 (PID: $mysql_pid)，准备终止..."
        
        # 确保不杀掉自己
        current_pid=$$
        if [ "$mysql_pid" != "$current_pid" ]; then
            # 终止 MySQL 进程
            kill -9 $mysql_pid
            if [ $? -ne 0 ]; then
                echo "错误：无法终止 MySQL 进程 (PID: $mysql_pid)。"
                exit 1
            fi
            echo "成功终止 MySQL 进程 (PID: $mysql_pid)。"
        else
            echo "当前进程与 MySQL 进程同名，未进行操作。"
        fi
    else
        echo "未发现正在运行的 MySQL 进程。"
    fi

    # 删除旧的 MySQL 安装目录和数据
    if [ -d "$INSTALL_DIR" ]; then
        echo "删除 MySQL 安装目录..."
        rm -rf $INSTALL_DIR
        if [ $? -eq 0 ]; then
            echo "成功删除 MySQL 安装目录 $INSTALL_DIR。"
        else
            echo "错误：无法删除 MySQL 安装目录 $INSTALL_DIR。"
            exit 1
        fi
    fi

    # 删除旧的 MySQL 源代码目录
    if [ -d "$SRC_DIR" ]; then
        echo "删除 MySQL 源代码目录..."
        rm -rf $SRC_DIR
        if [ $? -eq 0 ]; then
            echo "成功删除 MySQL 源代码目录 $SRC_DIR。"
        else
            echo "错误：无法删除 MySQL 源代码目录 $SRC_DIR。"
            exit 1
        fi
    fi

    # 删除旧的 MySQL 安装包
    if [ -f "$DOWNLOAD_DIR/mysql-$MYSQL_VERSION.tar.gz" ]; then
        echo "删除旧的 MySQL 安装包..."
        rm -f $DOWNLOAD_DIR/mysql-$MYSQL_VERSION.tar.gz
        if [ $? -eq 0 ]; then
            echo "成功删除旧的 MySQL 安装包。"
        else
            echo "错误：无法删除 MySQL 安装包。"
            exit 1
        fi
    fi
}

# 替换为阿里云镜像源
replace_with_aliyun_mirror() {
    echo "-----------------------------检查并替换镜像源--------------------------------------"
    if grep -q "mirrors.aliyun.com" /etc/yum.repos.d/CentOS-Base.repo; then
        echo "已使用阿里云镜像源，跳过替换。"
    else
        echo "替换为阿里云镜像源..."
        sudo cp /etc/yum.repos.d/CentOS-Base.repo /etc/yum.repos.d/CentOS-Base.repo.bak
        sudo curl -o /etc/yum.repos.d/CentOS-Base.repo http://mirrors.aliyun.com/repo/Centos-7.repo
        sudo yum clean all
        sudo yum makecache
        if [ $? -ne 0 ]; then
            echo "错误：替换阿里云镜像源失败。"
            exit 1
        fi
        echo "成功替换为阿里云镜像源。"
    fi
}

# 安装必要的依赖
install_dependencies() {
    echo "-----------------------------检查和安装依赖--------------------------------------"
    sudo yum install -y gcc gcc-c++ ncurses-devel openssl openssl-devel bison bzip2 make cmake perl wget
    if [ $? -ne 0 ]; then
        echo "错误：安装依赖失败，请检查网络连接或软件源。"
        exit 1
    fi
}

# 下载并解压 MySQL 源码到 /usr/local/mysql-版本号-src
download_and_extract_mysql() {
    echo "-----------------------------下载 MySQL 源码--------------------------------------"
    cd $DOWNLOAD_DIR
    if [ -f "mysql-$MYSQL_VERSION.tar.gz" ];then
        echo "MySQL 源码包已存在，跳过下载。"
    else
        wget -O mysql-$MYSQL_VERSION.tar.gz $MYSQL_SOURCE_URL
        if [ $? -ne 0 ];then
            echo "错误：下载 MySQL 源码包失败。"
            exit 1
        fi
    fi
    tar -zxvf mysql-$MYSQL_VERSION.tar.gz -C /usr/local
    mv /usr/local/mysql-$MYSQL_VERSION /usr/local/mysql-$MYSQL_VERSION-src
}

# 检查解压目录是否存在（后置校验）
check_extracted_files() {
    if [ ! -d "$SRC_DIR" ]; then
        echo "错误：解压 MySQL 源码文件失败，请检查 tar 包是否完整。"
        exit 1
    fi
}

# 下载并解压 Boost 库到 /usr/local/boost
download_and_extract_boost() {
    echo "-----------------------------下载 Boost 库--------------------------------------"
    if [ -d "$BOOST_DIR" ]; then
        echo "Boost 库已存在，跳过下载。"
    else
        mkdir -p $BOOST_DIR
        cd $DOWNLOAD_DIR
        wget -O boost_$BOOST_VERSION.tar.gz $BOOST_SOURCE_URL --no-check-certificate
        if [ $? -ne 0 ];then
            echo "错误：下载 Boost 库失败。"
            exit 1
        fi
        # 解压 Boost 并直接放置在 /usr/local/boost
        tar -zxvf boost_$BOOST_VERSION.tar.gz -C $BOOST_DIR --strip-components=1
        if [ $? -ne 0 ];then
            echo "错误：解压 Boost 库失败。"
            exit 1
        fi
    fi

    # 验证解压是否成功
    if [ "$(ls -A $BOOST_DIR)" ]; then
        echo "Boost 库解压成功。"
    else
        echo "错误：Boost 库解压失败，目录为空。"
        exit 1
    fi
}

# 编译 MySQL 源码
compile_mysql() {
    echo "-----------------------------编译 MySQL 源码--------------------------------------"
    cd $SRC_DIR
    cmake . -DCMAKE_INSTALL_PREFIX=$INSTALL_DIR \
        -DMYSQL_DATADIR=$DATA_DIR \
        -DSYSCONFDIR=/etc \
        -DWITH_SSL=system \
        -DWITH_ZLIB=system \
        -DDOWNLOAD_BOOST=1 \
        -DWITH_BOOST=$BOOST_DIR

    make -j "$(nproc)"
    if [ $? -ne 0 ]; then
        echo "错误：编译 MySQL 源码失败。"
        exit 1
    fi
    sudo make install
}

# 创建 MySQL 用户和组
create_mysql_user() {
    echo "-----------------------------创建 MySQL 用户和组--------------------------------------"
    if ! id -u mysql >/dev/null 2>&1; then
        groupadd mysql
        useradd -r -g mysql mysql
    fi
}

# 配置 MySQL
configure_mysql() {
    echo "-----------------------------配置 MySQL--------------------------------------"
    
    # 配置 MySQL 参数文件，包含 binlog 配置
    cat <<EOF > /etc/my.cnf
############### 客户端配置 ###############
[client]
port   = 3306
socket = $DATA_DIR/mysql.sock

############### 服务端配置 ###############
[mysqld]
port = 3306
autocommit     = ON
character-set-server   = utf8mb4
collation-server       = utf8mb4_general_ci
default-storage-engine = INNODB
basedir        = $INSTALL_DIR
datadir        = $DATA_DIR
tmpdir         = $TMP_DIR
pid-file       = $DATA_DIR/mysql.pid
socket         = $DATA_DIR/mysql.sock
lower_case_table_names = 1

# 允许所有 IP 访问
bind-address = 0.0.0.0

# Binary Logging 配置
log-bin = $BINLOG_DIR/mysql-bin  # 二进制日志
binlog_format = ROW
server-id = 1
max_binlog_size = 1G  # 设置 binlog 文件大小为 1GB

# General Query Log 配置
general_log = 1
general_log_file = $LOG_DIR/general.log  # 通用查询日志

# Slow Query Log 配置
slow_query_log = 1
slow_query_log_file = $LOG_DIR/slow.log  # 慢查询日志
long_query_time = 2  # 超过2秒的查询将被记录

# Relay Log 配置 (在主从复制时使用)
relay_log = $LOG_DIR/relay-log  # 中继日志

# Error Log 配置
log-error      = $LOG_DIR/error.log  # 记录 MySQL 启动、停止以及运行过程中遇到的错误、警告和其他重要事件

[mysql]
#关闭自动补全sql命令功能
no-auto-rehash
EOF

    if [ $? -ne 0 ];then
        echo "错误：MySQL 配置文件写入失败。"
        exit 1
    fi
}

# 创建必要的目录，日志、binlog 和 tmp 目录等
create_directories() {
    echo "-----------------------------创建必要的目录--------------------------------------"
    # 创建数据目录，仅在初始化前创建数据目录
    mkdir -p $DATA_DIR
    # 确保创建的目录具有正确的权限
    chown -R mysql:mysql $DATA_DIR
    chmod -R 750 $DATA_DIR

    # 创建日志目录、二进制日志目录和临时目录
    mkdir -p $LOG_DIR $BINLOG_DIR $TMP_DIR
    chown -R mysql:mysql $LOG_DIR $BINLOG_DIR $TMP_DIR
    chmod -R 750 $LOG_DIR $BINLOG_DIR $TMP_DIR
}


# 初始化 MySQL 数据库，使用配置文件
initialize_mysql() {
    echo "-----------------------------初始化 MySQL 数据库--------------------------------------"

    # 检查安装目录是否存在
    if [ ! -d "$INSTALL_DIR" ]; then
        echo "错误：MySQL 安装目录 $INSTALL_DIR 不存在，无法进行初始化。"
        exit 1
    fi

    # 检查 mysqld 二进制文件是否存在
    if [ ! -f "$INSTALL_DIR/bin/mysqld" ]; then
        echo "错误：无法找到 $INSTALL_DIR/bin/mysqld 文件，请检查 MySQL 是否正确安装。"
        exit 1
    fi

    # 检查配置文件是否存在
    if [ ! -f "/etc/my.cnf" ]; then
        echo "错误：配置文件 /etc/my.cnf 不存在，无法进行初始化。"
        exit 1
    fi

    # 进行 MySQL 初始化
    $INSTALL_DIR/bin/mysqld --defaults-file=/etc/my.cnf --user=mysql --initialize
    if [ $? -ne 0 ]; then
        echo "错误：MySQL 数据库初始化失败。"
        exit 1
    else
        echo "MySQL 数据库初始化成功。"
    fi
}


# 重新设置安装目录的权限
set_directory_permissions() {
    echo "-----------------------------设置 MySQL 安装目录的权限--------------------------------------"
    chown -R mysql:mysql $INSTALL_DIR
    if [ $? -eq 0 ]; then
        echo "成功设置 MySQL 安装目录的权限为 mysql 用户。"
    else
        echo "错误：无法设置 MySQL 安装目录的权限。"
        exit 1
    fi
}

# 启动 MySQL
start_mysql() {
    echo "-----------------------------启动 MySQL 服务--------------------------------------"
    $INSTALL_DIR/bin/mysqld_safe --defaults-file=/etc/my.cnf --user=mysql &
    sleep 5
    if pgrep -x "mysqld" >/dev/null;then
        echo "MySQL 服务已启动成功。"
    else
        echo "MySQL 服务启动失败，请检查日志。"
        exit 1
    fi
}

# 设置 root 密码为 123456
set_root_password() {
    echo "-----------------------------设置 root 密码--------------------------------------"

    # 定义日志文件路径
    LOG_FILE="$LOG_DIR/error.log"
    
    # 检查日志文件是否存在
    if [ ! -f "$LOG_FILE" ]; then
        echo "错误：日志文件 $LOG_FILE 不存在，请检查 MySQL 是否正确启动。"
        exit 1
    fi

    # 使用更精确的正则表达式查找临时密码
    temp_password=$(grep 'temporary password' $LOG_FILE | awk '{print $NF}')
    
    # 检查是否成功获取临时密码
    if [ -z "$temp_password" ];then
        echo "错误：未找到临时密码。请检查 MySQL 日志文件中的临时密码。"
        exit 1
    fi

    # 根据 MySQL 版本区分密码设置命令
    if [[ "$MYSQL_VERSION" =~ 8.0.* ]];then
        # MySQL 8.0 使用 ALTER USER 设置密码
        $INSTALL_DIR/bin/mysql -uroot -p"$temp_password" --connect-expired-password --execute="ALTER USER 'root'@'localhost' IDENTIFIED BY '$MYSQL_ROOT_PASSWORD';"
    elif [[ "$MYSQL_VERSION" =~ 5.7.* ]];then
        # MySQL 5.7 使用 SET PASSWORD 设置密码
        $INSTALL_DIR/bin/mysql -uroot -p"$temp_password" --connect-expired-password --execute="SET PASSWORD FOR 'root'@'localhost' = PASSWORD('$MYSQL_ROOT_PASSWORD');"
    else
        echo "错误：不支持的 MySQL 版本 $MYSQL_VERSION。"
        exit 1
    fi

    # 检查是否成功修改密码
    if [ $? -eq 0 ];then
        echo "root 密码已成功设置为 '$MYSQL_ROOT_PASSWORD'"
    else
        echo "错误：设置 root 密码失败。"
        exit 1
    fi
}


# 设置环境变量
configure_environment_variables() {
    echo "-----------------------------设置 MySQL 环境变量--------------------------------------"
    
    # 检查环境变量文件
    ENV_FILE="/etc/profile.d/mysql_env.sh"
    
    # 如果环境变量文件已存在，先备份
    if [ -f "$ENV_FILE" ]; then
        BACKUP_FILE="/etc/profile.d/mysql_env.sh.bak_$(date +%F_%T)"
        echo "检测到已有 MySQL 环境变量文件，正在备份为 $BACKUP_FILE"
        mv $ENV_FILE $BACKUP_FILE
        if [ $? -ne 0 ]; then
            echo "错误：备份环境变量文件失败。"
            exit 1
        else
            echo "成功备份环境变量文件。"
        fi
    fi

    # 设置 MySQL 的 PATH 变量
    cat <<EOF > $ENV_FILE
export PATH=\$PATH:$INSTALL_DIR/bin
EOF

    # 加载环境变量，使其立即生效
    source $ENV_FILE

    echo "MySQL 环境变量已设置并加载成功"
}


# 删除源代码目录以节省空间
clean_source_directory() {
    echo "-----------------------------清理解压的源代码目录--------------------------------------"
    rm -rf $SRC_DIR
    if [ $? -eq 0 ];then
        echo "成功删除源代码目录。"
    else
        echo "错误：删除源代码目录失败。"
        exit 1
    fi
}



# 设置定时任务
configure_cron_jobs() {
    echo "-----------------------------配置定时任务--------------------------------------"
    
    # 创建备份目录
    if [ ! -d "$BACKUP_DIR" ];then
        mkdir -p $BACKUP_DIR
        chown mysql:mysql $BACKUP_DIR
    fi

    # 备份数据库的定时任务 - 每天凌晨2点备份
    echo "0 2 * * * /usr/bin/mysqldump -u root -p'$MYSQL_ROOT_PASSWORD' --all-databases > $BACKUP_DIR/mysql_backup_\$(date +\%F).sql" >> /etc/crontab

    # 清理超过7天的 binlog 文件 - 每天凌晨3点清理
    echo "0 3 * * * /usr/bin/find $BINLOG_DIR -name 'mysql-bin.*' -mtime +7 -exec rm {} \;" >> /etc/crontab

    # 重启 cron 服务以应用任务
    sudo systemctl restart crond
}

# 验证 MySQL 安装
validate_mysql_installation() {
    echo "-----------------------------验证 MySQL 安装--------------------------------------"
    
    # 验证 MySQL 服务是否运行
    if pgrep -x "mysqld" > /dev/null; then
        echo "MySQL 服务正在运行"
    else
        echo "错误：MySQL 服务未能启动，请检查日志"
        exit 1
    fi

    # 验证 MySQL 版本
    MYSQL_VERSION_OUTPUT=$($INSTALL_DIR/bin/mysql --version)
    if [[ "$MYSQL_VERSION_OUTPUT" == *"$MYSQL_VERSION"* ]]; then
        echo "MySQL 安装成功，版本：$MYSQL_VERSION_OUTPUT"
    else
        echo "错误：MySQL 版本验证失败"
        exit 1
    fi
}

# 开放 3306 端口并检查防火墙状态
configure_firewall() {
    echo "-----------------------------检查并开放 3306 端口--------------------------------------"

    # 检查防火墙服务状态
    firewall_status=$(sudo systemctl is-active firewalld)

    if [ "$firewall_status" == "active" ]; then
        echo "防火墙已启用，正在检查并开放 3306 端口..."

        # 检查 3306 端口是否已开放
        if sudo firewall-cmd --list-ports | grep -q "3306/tcp"; then
            echo "3306 端口已开放，无需再次操作。"
        else
            # 开放 3306 端口
            sudo firewall-cmd --zone=public --add-port=3306/tcp --permanent
            sudo firewall-cmd --reload
            if [ $? -eq 0 ]; then
                echo "成功开放 3306 端口。"
            else
                echo "错误：无法开放 3306 端口。"
                exit 1
            fi
        fi
    else
        echo "防火墙未启用，无需开放端口。"
    fi
}

# 配置 MySQL 开机自启动服务
# 配置 MySQL 开机自启动服务
configure_mysql_autostart_service() {
    echo "-----------------------------配置 MySQL 开机自启动服务--------------------------------------"

    # 创建 systemd 服务文件
    cat <<EOF > /etc/systemd/system/mysql.service
[Unit]
Description=MySQL Server
After=network.target

[Service]
Type=forking
User=mysql
Group=mysql
ExecStart=$INSTALL_DIR/support-files/mysql.server start --defaults-file=/etc/my.cnf
ExecStop=$INSTALL_DIR/support-files/mysql.server stop --defaults-file=/etc/my.cnf
Restart=on-failure
RestartSec=5                    
TimeoutSec=600                  
LimitNOFILE=65535               

[Install]
WantedBy=multi-user.target
EOF

    # 重载 systemd 服务配置
    systemctl daemon-reload

    # 设置 MySQL 服务为开机自启动
    systemctl enable mysql

    # 检查是否成功设置为开机自启动
    if [ $? -eq 0 ]; then
        echo "MySQL 已成功配置为开机自启动服务。"
    else
        echo "错误：配置 MySQL 开机自启动失败。"
        exit 1
    fi
}

# 打印 MySQL 服务管理提示
print_mysql_service_info() {
    echo "-----------------------------MySQL 服务管理信息--------------------------------------"
    echo "MySQL $MYSQL_VERSION 已成功安装并启动。"
    echo "MySQL root 密码: '$MYSQL_ROOT_PASSWORD'"
    echo "您可以使用以下命令来启动或停止 MySQL 服务："
    echo "启动服务: $INSTALL_DIR/bin/mysqld_safe --defaults-file=/etc/my.cnf --user=mysql &"
    echo "停止服务: killall mysqld"
    echo "查看 MySQL 进程: pgrep mysqld"
}



# 主函数
main() {
    select_mysql_version
    check_disk_space
    terminate_existing_mysql  # 先检查并终止 MySQL 进程，并清理旧的历史数据和安装包
    replace_with_aliyun_mirror
    install_dependencies
    download_and_extract_mysql
    check_extracted_files
    download_and_extract_boost
    compile_mysql
    create_mysql_user
    configure_mysql # 配置 MySQL my.cnf
    create_directories # 初始化前创建 datadir
    initialize_mysql # 初始化
    start_mysql
    set_root_password
    configure_environment_variables # 设置环境变量
    set_directory_permissions  # 设置 MySQL 安装目录的权限
    configure_cron_jobs
    validate_mysql_installation # 验证mysql 安装结果
    configure_firewall # 检查并开放 3306 端口
    configure_mysql_autostart_service # 配置 MySQL 开机自启动服务
    print_mysql_service_info
    clean_source_directory  # 清理源代码目录
}

# 执行主程序
main
