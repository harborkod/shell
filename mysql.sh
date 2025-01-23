#!/bin/bash

# 引入日志函数
source ./harborkod-setup.sh

# ==============================================
# MySQL 相关变量
# ==============================================
MYSQL_VERSION="8.0.24"
MYSQL_USER="mysql"
MYSQL_GROUP="mysql"
MYSQL_ROOT_PASSWORD="harborKod@mysql@admin"
MYSQL_SOURCE_URL="https://mirrors.huaweicloud.com/mysql/Downloads/MySQL-8.0/mysql-8.0.24.tar.gz"

# 标准目录结构
MYSQL_INSTALL_DIR="/usr/local/mysql"                # 程序安装目录
MYSQL_CONF_DIR="/etc/mysql"                         # 配置文件目录
MYSQL_LOG_DIR="/var/log/mysql"                      # 日志目录
MYSQL_DATA_DIR="/var/lib/mysql"                     # 数据目录
MYSQL_PID_DIR="/var/run/mysql"                      # PID 文件目录
MYSQL_BACKUP_DIR="/var/backup/mysql"                # 备份目录
MYSQL_TMP_DIR="/var/tmp/mysql"                      # 临时文件目录
MYSQL_BINLOG_DIR="/var/log/mysql/binlog"           # 二进制日志目录
MYSQL_SRC_DIR="/usr/local/src/mysql-${MYSQL_VERSION}"  # 源码目录

# Boost 相关变量
BOOST_VERSION="1_59_0"
BOOST_SOURCE_URL="https://sourceforge.net/projects/boost/files/boost/1.59.0/boost_1_59_0.tar.gz/download"
BOOST_INSTALL_DIR="/usr/local/boost"


# ==============================================
# MySQL 通用函数
# ==============================================
mysql_common_cleanup() {
    print_section "清理系统环境"
    
    # 1. 停止服务和进程
    print_step "停止 MySQL 服务和进程..."
    if systemctl is-active mysql >/dev/null 2>&1; then
        systemctl stop mysql
        systemctl disable mysql
        print_success "MySQL 服务已停止并禁用"
    fi
    
    local mysql_pid=$(pgrep -x mysqld)
    if [ -n "$mysql_pid" ]; then
        kill -15 $mysql_pid
        sleep 2
        if kill -0 $mysql_pid 2>/dev/null; then
            kill -9 $mysql_pid
        fi
        print_success "MySQL 进程已终止"
    fi

    # 2. 清理所有相关目录
    print_step "清理目录..."
    local dirs=(
        "$MYSQL_INSTALL_DIR"      # 安装目录
        "$MYSQL_CONF_DIR"         # 配置目录
        "$MYSQL_LOG_DIR"          # 日志目录
        "$MYSQL_DATA_DIR"         # 数据目录
        "$MYSQL_PID_DIR"          # PID目录
        "$MYSQL_BACKUP_DIR"       # 备份目录
        "$MYSQL_TMP_DIR"          # 临时目录
        "$MYSQL_BINLOG_DIR"       # 二进制日志目录
        "$MYSQL_SRC_DIR"          # 源码目录
        "$BOOST_INSTALL_DIR"      # Boost库目录
        "/usr/local/src/mysql*"   # 其他可能的源码目录
        "/usr/local/mysql*"       # 其他可能的安装目录
    )

    for dir in "${dirs[@]}"; do
        rm -rf $dir
        print_success "已清理目录: $dir"
    done

    # 3. 清理系统服务和配置文件
    print_step "清理系统服务和配置..."
    local config_files=(
        "/etc/systemd/system/mysql.service"
        "/etc/systemd/system/mysqld.service"
        "/etc/init.d/mysql"
        "/etc/init.d/mysqld"
        "/etc/my.cnf"
        "/etc/my.cnf.d"
        "/etc/mysql"
    )

    for file in "${config_files[@]}"; do
        rm -rf $file
    done
    systemctl daemon-reload
    print_success "服务配置已清理"

    # 4. 清理环境变量
    print_step "清理环境变量..."
    rm -f /etc/profile.d/mysql.sh
    rm -f /etc/profile.d/mysql_env.sh
    unset MYSQL_HOME
    mysql_common_cleanup_path
    print_success "环境变量已清理"

    # 5. 清理用户和组
    print_step "清理用户和组..."
    local users=("mysql" "mysqld" "$MYSQL_USER")
    local groups=("mysql" "mysqld" "$MYSQL_GROUP")

    for user in "${users[@]}"; do
        if id "$user" >/dev/null 2>&1; then
            userdel -rf "$user"
        fi
    done

    for group in "${groups[@]}"; do
        if getent group "$group" >/dev/null; then
            groupdel "$group"
        fi
    done
    print_success "用户和组已清理"

    # 6. 清理所有临时文件和下载文件
    print_step "清理临时文件和下载文件..."
    rm -rf /tmp/mysql*
    rm -rf /var/tmp/mysql*
    rm -f /opt/mysql-*.tar.gz
    rm -f /opt/boost_*.tar.gz
    print_success "临时文件已清理"

    # 7. 清理日志文件
    print_step "清理日志文件..."
    rm -rf /var/log/mysql*
    rm -rf /var/log/mysqld*
    print_success "日志文件已清理"

    # 8. 清理定时任务
    print_step "清理定时任务..."
    sed -i '/mysql/d' /etc/crontab
    sed -i '/mysqld/d' /etc/crontab
    sed -i '/mysql_backup/d' /etc/crontab
    sed -i '/mysql-bin/d' /etc/crontab
    print_success "定时任务已清理"

    # 9. 清理系统链接
    print_step "清理系统链接..."
    rm -f /usr/bin/mysql*
    rm -f /usr/local/bin/mysql*
    print_success "系统链接已清理"

    print_success "系统环境清理完成"
}

mysql_common_check_dependencies() {
    print_section "检查 MySQL 安装依赖"
    
    # 检查 root 权限
    if [ "$EUID" -ne 0 ] && ! command -v sudo >/dev/null 2>&1; then
        print_error "此脚本需要 root 权限或 sudo 命令"
        exit 1
    fi

    # 检查必要的命令
    for cmd in wget tar gcc make cmake bison perl; do
        if ! command -v $cmd >/dev/null 2>&1; then
            print_warning "未检测到 $cmd 命令，正在安装..."
            if command -v yum >/dev/null 2>&1; then
                sudo yum install -y $cmd
            elif command -v apt-get >/dev/null 2>&1; then
                sudo apt-get install -y $cmd
            else
                print_error "无法自动安装 $cmd，请手动安装"
                exit 1
            fi
            print_success "$cmd 安装完成"
        else
            print_success "$cmd 已安装"
        fi
    done
}

mysql_common_check_processes() {
    print_section "检查 MySQL 进程"
    print_step "检查是否有正在运行的 MySQL 进程..."
    
    local mysql_pid=$(pgrep -x mysqld)
    if [ -n "$mysql_pid" ]; then
        print_warning "检测到正在运行的 MySQL 进程 (PID: $mysql_pid)"
        kill -15 $mysql_pid
        sleep 2
        if kill -0 $mysql_pid 2>/dev/null; then
            kill -9 $mysql_pid
        fi
        print_success "MySQL 进程已终止"
    else
        print_info "未检测到运行中的 MySQL 进程"
    fi
}

mysql_common_cleanup_path() {
    # 保存原始 IFS
    local OIFS="$IFS"
    IFS=':'
    
    # 将 PATH 转换为数组
    local -a paths=($PATH)
    declare -A unique_paths
    local new_path=""
    
    for p in "${paths[@]}"; do
        if [[ "$p" != *"mysql"* ]]; then
            if [[ -z "${unique_paths[$p]}" ]]; then
                unique_paths[$p]=1
                if [ -z "$new_path" ]; then
                    new_path="$p"
                else
                    new_path="$new_path:$p"
                fi
            fi
        fi
    done
    
    IFS="$OIFS"
    export PATH="$new_path"
}

# ==============================================
# MySQL 安装相关函数
# ==============================================
mysql_install_select_version() {
    print_section "选择 MySQL 版本"
    print_info "请选择要安装的 MySQL 版本："
    print_info "1) MySQL 5.7.37"
    print_info "2) MySQL 8.0.24"
    read -p "[$(date '+%Y-%m-%d %H:%M:%S')] [INPUT] - 请输入选项 [1-2]: " choice

    case $choice in
        1)
            MYSQL_VERSION="5.7.37"
            MYSQL_SOURCE_URL="https://mirrors.huaweicloud.com/mysql/Downloads/MySQL-5.7/mysql-5.7.37.tar.gz"
            ;;
        2)
            MYSQL_VERSION="8.0.24"
            MYSQL_SOURCE_URL="https://mirrors.huaweicloud.com/mysql/Downloads/MySQL-8.0/mysql-8.0.24.tar.gz"
            ;;
        *)
            print_error "无效的选择"
            exit 1
            ;;
    esac

    print_success "已选择: MySQL ${MYSQL_VERSION}"
}

mysql_install_prepare_directories() {
    print_section "准备目录结构"
    
    # 创建标准目录结构
    print_step "创建必要的目录..."
    for dir in \
        "$MYSQL_INSTALL_DIR" \
        "$MYSQL_CONF_DIR" \
        "$MYSQL_LOG_DIR" \
        "$MYSQL_DATA_DIR" \
        "$MYSQL_PID_DIR" \
        "$MYSQL_BACKUP_DIR" \
        "$MYSQL_TMP_DIR" \
        "$MYSQL_BINLOG_DIR" \
        "$MYSQL_SRC_DIR"; do
        if ! mkdir -p "$dir"; then
            print_error "创建目录失败: $dir"
            exit 1
        fi
        print_success "创建目录: $dir"
    done

    # 设置基本权限
    chmod 755 "$MYSQL_INSTALL_DIR"
    chmod 750 "$MYSQL_CONF_DIR"
    chmod 750 "$MYSQL_LOG_DIR"
    chmod 750 "$MYSQL_DATA_DIR"
    chmod 750 "$MYSQL_PID_DIR"
    chmod 750 "$MYSQL_BACKUP_DIR"
    chmod 750 "$MYSQL_TMP_DIR"
    chmod 750 "$MYSQL_BINLOG_DIR"
    
    print_success "目录结构准备完成"
}

# 检查是否有足够磁盘空间（前置校验）
mysql_common_check_disk_space() {
    AVAILABLE_SPACE=$(df /usr/local | tail -1 | awk '{print $4}')
    if [ "$AVAILABLE_SPACE" -lt 5000000 ]; then
        print_error "磁盘空间不足，至少需要 5GB 可用空间。"
        exit 1
    fi
}

# 安装必要的依赖
install_dependencies() {
    print_section "检查和安装依赖"
    print_step "安装必要的依赖包..."
    sudo yum install -y gcc gcc-c++ ncurses-devel openssl openssl-devel bison bzip2 make cmake perl wget
    if [ $? -ne 0 ]; then
        print_error "安装依赖失败，请检查网络连接或软件源"
        exit 1
    fi
    print_success "依赖包安装完成"
}

# MySQL 安装相关函数
mysql_install_download_package() {
    print_section "下载 MySQL 源码"
    cd "$DOWNLOAD_BASE_DIR"
    
    local package_name="mysql-${MYSQL_VERSION}.tar.gz"
    if [ -f "$package_name" ]; then
        print_info "MySQL 源码包已存在，跳过下载"
    else
        print_step "下载 MySQL 源码包..."
        if ! wget -O "$package_name" "$MYSQL_SOURCE_URL"; then
            print_error "下载 MySQL 源码包失败"
            exit 1
        fi
        print_success "下载完成"
    fi

    print_step "解压源码包..."
    tar -zxf "$package_name" -C /usr/local/
    mv "/usr/local/mysql-${MYSQL_VERSION}" "$MYSQL_SRC_DIR"
    print_success "解压完成"
}

mysql_install_download_boost() {
    print_section "下载 Boost 库"
    if [ -d "$BOOST_INSTALL_DIR" ]; then
        print_info "Boost 库已存在，跳过下载"
        return 0
    fi

    print_step "创建 Boost 安装目录..."
    mkdir -p "$BOOST_INSTALL_DIR"
    cd "$DOWNLOAD_BASE_DIR"
    
    print_step "下载 Boost 库..."
    if ! wget -O "boost_${BOOST_VERSION}.tar.gz" "$BOOST_SOURCE_URL" --no-check-certificate; then
        print_error "下载 Boost 库失败"
        exit 1
    fi

    print_step "解压 Boost 库..."
    if ! tar -zxf "boost_${BOOST_VERSION}.tar.gz" -C "$BOOST_INSTALL_DIR" --strip-components=1; then
        print_error "解压 Boost 库失败"
        exit 1
    fi

    if [ "$(ls -A $BOOST_INSTALL_DIR)" ]; then
        print_success "Boost 库安装完成"
    else
        print_error "Boost 库安装失败，目录为空"
        exit 1
    fi
}

mysql_install_compile() {
    print_section "编译 MySQL"
    cd "$MYSQL_SRC_DIR"

    print_step "配置编译参数..."
    cmake . -DCMAKE_INSTALL_PREFIX="$MYSQL_INSTALL_DIR" \
        -DMYSQL_DATADIR="$MYSQL_DATA_DIR" \
        -DSYSCONFDIR="$MYSQL_CONF_DIR" \
        -DWITH_SSL=system \
        -DWITH_ZLIB=system \
        -DDOWNLOAD_BOOST=1 \
        -DWITH_BOOST="$BOOST_INSTALL_DIR"

    if [ $? -ne 0 ]; then
        print_error "配置编译参数失败"
        exit 1
    fi

    print_step "开始编译..."
    make -j "$(nproc)"
    if [ $? -ne 0 ]; then
        print_error "编译失败"
        exit 1
    fi

    print_step "安装到指定目录..."
    if ! make install; then
        print_error "安装失败"
        exit 1
    fi

    print_success "编译安装完成"
}

mysql_install_configure() {
    print_section "配置 MySQL"
    print_step "创建配置文件..."
    
    cat > "$MYSQL_CONF_DIR/my.cnf" <<EOF
# MySQL 配置文件
[client]
port   = 3306
socket = $MYSQL_DATA_DIR/mysql.sock

[mysqld]
# 基本配置
port = 3306
basedir = $MYSQL_INSTALL_DIR
datadir = $MYSQL_DATA_DIR
tmpdir  = $MYSQL_TMP_DIR
socket  = $MYSQL_DATA_DIR/mysql.sock
pid-file = $MYSQL_PID_DIR/mysql.pid

# 字符集配置
character-set-server = utf8mb4
collation-server = utf8mb4_general_ci

# 存储引擎配置
default-storage-engine = INNODB
innodb_file_per_table = 1

# 日志配置
log-error = $MYSQL_LOG_DIR/error.log
slow_query_log = 1
slow_query_log_file = $MYSQL_LOG_DIR/slow.log
long_query_time = 2

# 二进制日志配置
log-bin = $MYSQL_BINLOG_DIR/mysql-bin
binlog_format = ROW
expire_logs_days = 7
max_binlog_size = 1G

# 其他优化配置
max_connections = 1000
open_files_limit = 65535
table_open_cache = 2048
max_allowed_packet = 16M
EOF

    if [ $? -ne 0 ]; then
        print_error "配置文件创建失败"
        exit 1
    fi
    print_success "配置文件创建完成"
}

# 创建 MySQL 用户和组
create_mysql_user() {
    print_section "创建 MySQL 用户和组"
    if ! id -u $MYSQL_USER >/dev/null 2>&1; then
        print_step "创建用户组和用户..."
        groupadd $MYSQL_GROUP
        useradd -r -g $MYSQL_GROUP $MYSQL_USER
        print_success "MySQL 用户和组创建完成"
    else
        print_info "MySQL 用户已存在，跳过创建"
    fi
}

# 创建必要的目录，日志、binlog 和 tmp 目录等
create_directories() {
    print_section "创建必要的目录"
    
    print_step "创建数据目录..."
    mkdir -p $MYSQL_DATA_DIR
    print_step "设置数据目录权限..."
    chown -R $MYSQL_USER:$MYSQL_GROUP $MYSQL_DATA_DIR
    chmod -R 750 $MYSQL_DATA_DIR
    print_success "数据目录创建完成"

    print_step "创建日志和临时目录..."
    mkdir -p $MYSQL_LOG_DIR $MYSQL_BINLOG_DIR $MYSQL_TMP_DIR
    chown -R $MYSQL_USER:$MYSQL_GROUP $MYSQL_LOG_DIR $MYSQL_BINLOG_DIR $MYSQL_TMP_DIR
    chmod -R 750 $MYSQL_LOG_DIR $MYSQL_BINLOG_DIR $MYSQL_TMP_DIR
    print_success "日志和临时目录创建完成"
}


# 初始化 MySQL 数据库，使用配置文件
mysql_install_initialize() {
    print_section "初始化 MySQL 数据库"

    # 检查安装目录是否存在
    if [ ! -d "$MYSQL_INSTALL_DIR" ]; then
        print_error "MySQL 安装目录 $MYSQL_INSTALL_DIR 不存在，无法进行初始化"
        exit 1
    fi

    # 检查 mysqld 二进制文件是否存在
    if [ ! -f "$MYSQL_INSTALL_DIR/bin/mysqld" ]; then
        print_error "无法找到 $MYSQL_INSTALL_DIR/bin/mysqld 文件，请检查 MySQL 是否正确安装"
        exit 1
    fi

    # 检查配置文件是否存在
    if [ ! -f "$MYSQL_CONF_DIR/my.cnf" ]; then
        print_error "配置文件 $MYSQL_CONF_DIR/my.cnf 不存在，无法进行初始化"
        exit 1
    fi

    print_step "初始化 MySQL 数据库..."
    $MYSQL_INSTALL_DIR/bin/mysqld --defaults-file=$MYSQL_CONF_DIR/my.cnf --user=$MYSQL_USER --initialize
    if [ $? -ne 0 ]; then
        print_error "MySQL 数据库初始化失败"
        exit 1
    fi
    print_success "MySQL 数据库初始化成功"
}


# 重新设置安装目录的权限
set_directory_permissions() {
    print_section "设置 MySQL 安装目录的权限"
    print_step "设置目录权限..."
    chown -R $MYSQL_USER:$MYSQL_GROUP $MYSQL_INSTALL_DIR
    if [ $? -eq 0 ]; then
        print_success "成功设置 MySQL 安装目录的权限为 $MYSQL_USER 用户"
    else
        print_error "无法设置 MySQL 安装目录的权限"
        exit 1
    fi
}

# 启动 MySQL
mysql_install_start_service() {
    print_section "启动 MySQL 服务"
    print_step "启动 MySQL 服务..."
    $MYSQL_INSTALL_DIR/bin/mysqld_safe --defaults-file=$MYSQL_CONF_DIR/my.cnf --user=$MYSQL_USER &
    sleep 5
    if pgrep -x "mysqld" >/dev/null; then
        print_success "MySQL 服务已启动成功"
    else
        print_error "MySQL 服务启动失败，请检查日志"
        exit 1
    fi
}

# 设置 root 密码为 123456
mysql_install_set_password() {
    print_section "设置 root 密码"
    print_step "检查日志文件..."
    
    # 定义日志文件路径
    LOG_FILE="$MYSQL_LOG_DIR/error.log"
    
    # 检查日志文件是否存在
    if [ ! -f "$LOG_FILE" ]; then
        print_error "日志文件 $LOG_FILE 不存在，请检查 MySQL 是否正确启动"
        exit 1
    fi

    print_step "查找临时密码..."
    temp_password=$(grep 'temporary password' $LOG_FILE | awk '{print $NF}')
    
    if [ -z "$temp_password" ]; then
        print_error "未找到临时密码。请检查 MySQL 日志文件中的临时密码"
        exit 1
    fi

    print_step "设置新密码..."
    if [[ "$MYSQL_VERSION" =~ 8.0.* ]]; then
        $MYSQL_INSTALL_DIR/bin/mysql -uroot -p"$temp_password" --connect-expired-password \
            --execute="ALTER USER 'root'@'localhost' IDENTIFIED BY '$MYSQL_ROOT_PASSWORD';"
    elif [[ "$MYSQL_VERSION" =~ 5.7.* ]]; then
        $MYSQL_INSTALL_DIR/bin/mysql -uroot -p"$temp_password" --connect-expired-password \
            --execute="SET PASSWORD FOR 'root'@'localhost' = PASSWORD('$MYSQL_ROOT_PASSWORD');"
    else
        print_error "不支持的 MySQL 版本 $MYSQL_VERSION"
        exit 1
    fi

    if [ $? -eq 0 ]; then
        print_success "root 密码已成功设置为 '$MYSQL_ROOT_PASSWORD'"
    else
        print_error "设置 root 密码失败"
        exit 1
    fi
}


# 设置环境变量
configure_environment_variables() {
    print_section "设置 MySQL 环境变量"
    
    ENV_FILE="/etc/profile.d/mysql.sh"
    
    if [ -f "$ENV_FILE" ]; then
        BACKUP_FILE="/etc/profile.d/mysql.sh.bak_$(date +%F_%T)"
        print_step "检测到已有 MySQL 环境变量文件，正在备份..."
        mv $ENV_FILE $BACKUP_FILE
        if [ $? -ne 0 ]; then
            print_error "备份环境变量文件失败"
            exit 1
        fi
        print_success "成功备份环境变量文件"
    fi

    print_step "创建新的环境变量配置..."
    cat <<EOF > $ENV_FILE
# MySQL 环境变量配置
export MYSQL_HOME=${MYSQL_INSTALL_DIR}

# 确保 PATH 中不会重复添加 MySQL 路径
if [[ ":\$PATH:" != *":\$MYSQL_HOME/bin:"* ]]; then
    export PATH=\$PATH:\$MYSQL_HOME/bin
fi
EOF

    source $ENV_FILE
    print_success "MySQL 环境变量已设置并加载成功"
}


# 设置定时任务
mysql_install_configure_cron() {
    print_section "配置定时任务"
    
    # 创建备份目录
    if [ ! -d "$MYSQL_BACKUP_DIR" ]; then
        print_step "创建备份目录..."
        mkdir -p $MYSQL_BACKUP_DIR
        chown $MYSQL_USER:$MYSQL_GROUP $MYSQL_BACKUP_DIR
        print_success "备份目录创建完成"
    fi

    print_step "配置定时备份任务..."
    # 备份数据库的定时任务 - 每天凌晨2点备份
    echo "0 2 * * * /usr/bin/mysqldump -u root -p'$MYSQL_ROOT_PASSWORD' --all-databases > $MYSQL_BACKUP_DIR/mysql_backup_\$(date +\%F).sql" >> /etc/crontab

    print_step "配置日志清理任务..."
    # 清理超过7天的 binlog 文件 - 每天凌晨3点清理
    echo "0 3 * * * /usr/bin/find $MYSQL_BINLOG_DIR -name 'mysql-bin.*' -mtime +7 -exec rm {} \;" >> /etc/crontab

    # 重启 cron 服务以应用任务
    print_step "重启 cron 服务..."
    sudo systemctl restart crond
    print_success "定时任务配置完成"
}

# 验证 MySQL 安装
validate_mysql_installation() {
    print_section "验证 MySQL 安装"
    
    print_step "检查 MySQL 服务状态..."
    if pgrep -x "mysqld" > /dev/null; then
        print_success "MySQL 服务正在运行"
    else
        print_error "MySQL 服务未能启动，请检查日志"
        exit 1
    fi

    print_step "验证 MySQL 版本..."
    MYSQL_VERSION_OUTPUT=$($MYSQL_INSTALL_DIR/bin/mysql --version)
    if [[ "$MYSQL_VERSION_OUTPUT" == *"$MYSQL_VERSION"* ]]; then
        print_success "MySQL 安装成功，版本：$MYSQL_VERSION_OUTPUT"
    else
        print_error "MySQL 版本验证失败"
        exit 1
    fi
}

# 开放 3306 端口并检查防火墙状态
mysql_install_configure_firewall() {
    print_section "检查并开放 3306 端口"

    print_step "检查防火墙状态..."
    firewall_status=$(sudo systemctl is-active firewalld)

    if [ "$firewall_status" == "active" ]; then
        print_info "防火墙已启用，检查 3306 端口..."

        if sudo firewall-cmd --list-ports | grep -q "3306/tcp"; then
            print_info "3306 端口已开放，无需操作"
        else
            print_step "开放 3306 端口..."
            sudo firewall-cmd --zone=public --add-port=3306/tcp --permanent
            sudo firewall-cmd --reload
            if [ $? -eq 0 ]; then
                print_success "3306 端口已开放"
            else
                print_error "无法开放 3306 端口"
                exit 1
            fi
        fi
    else
        print_info "防火墙未启用，无需开放端口"
    fi
}

# 配置 MySQL 开机自启动服务
configure_mysql_autostart_service() {
    print_section "配置 MySQL 开机自启动服务"

    print_step "创建 systemd 服务文件..."
    cat <<EOF > /etc/systemd/system/mysql.service
[Unit]
Description=MySQL Server
After=network.target

[Service]
Type=forking
User=$MYSQL_USER
Group=$MYSQL_GROUP
ExecStart=$MYSQL_INSTALL_DIR/support-files/mysql.server start --defaults-file=$MYSQL_CONF_DIR/my.cnf
ExecStop=$MYSQL_INSTALL_DIR/support-files/mysql.server stop --defaults-file=$MYSQL_CONF_DIR/my.cnf
Restart=on-failure
RestartSec=5
TimeoutSec=600
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF

    print_step "重载 systemd 配置..."
    systemctl daemon-reload

    print_step "启用 MySQL 开机自启动..."
    systemctl enable mysql

    if [ $? -eq 0 ]; then
        print_success "MySQL 已配置为开机自启动服务"
    else
        print_error "配置 MySQL 开机自启动失败"
        exit 1
    fi
}

# 打印 MySQL 服务管理提示
print_mysql_service_info() {
    print_section "MySQL 服务管理信息"
    print_success "MySQL $MYSQL_VERSION 已成功安装并启动"
    print_info "MySQL root 密码: '$MYSQL_ROOT_PASSWORD'"
    print_info "服务管理命令："
    print_info "  启动服务: $MYSQL_INSTALL_DIR/bin/mysqld_safe --defaults-file=$MYSQL_CONF_DIR/my.cnf --user=$MYSQL_USER &"
    print_info "  停止服务: killall mysqld"
    print_info "  查看进程: pgrep mysqld"
}

mysql_install_create_user() {
    print_section "创建用户和权限"
    
    # 创建用户组
    if ! getent group "$MYSQL_GROUP" > /dev/null; then
        print_step "创建用户组..."
        groupadd "$MYSQL_GROUP"
        print_success "用户组创建完成"
    fi

    # 创建用户
    if ! id "$MYSQL_USER" > /dev/null 2>&1; then
        print_step "创建用户..."
        useradd -r -g "$MYSQL_GROUP" -d "$MYSQL_DATA_DIR" -s /usr/sbin/nologin "$MYSQL_USER"
        print_success "用户创建完成"
    fi

    # 设置目录权限
    print_step "设置目录权限..."
    chown -R "$MYSQL_USER:$MYSQL_GROUP" "$MYSQL_INSTALL_DIR"
    chown -R "$MYSQL_USER:$MYSQL_GROUP" "$MYSQL_DATA_DIR"
    chown -R "$MYSQL_USER:$MYSQL_GROUP" "$MYSQL_LOG_DIR"
    chown -R "$MYSQL_USER:$MYSQL_GROUP" "$MYSQL_PID_DIR"
    chown -R "$MYSQL_USER:$MYSQL_GROUP" "$MYSQL_TMP_DIR"
    chown -R "$MYSQL_USER:$MYSQL_GROUP" "$MYSQL_BINLOG_DIR"
    chown -R root:"$MYSQL_GROUP" "$MYSQL_CONF_DIR"
    
    # 设置权限
    chmod 755 "$MYSQL_INSTALL_DIR"
    chmod 750 "$MYSQL_DATA_DIR"
    chmod 750 "$MYSQL_LOG_DIR"
    chmod 750 "$MYSQL_PID_DIR"
    chmod 750 "$MYSQL_TMP_DIR"
    chmod 750 "$MYSQL_BINLOG_DIR"
    chmod 750 "$MYSQL_CONF_DIR"
    chmod 640 "$MYSQL_CONF_DIR/my.cnf"
    
    print_success "用户和权限配置完成"
}

mysql_install_configure_env() {
    print_section "配置环境变量"
    
    env_file="/etc/profile.d/mysql.sh"
    print_step "创建环境变量配置文件..."
    
    cat > "$env_file" <<EOF
# MySQL 环境变量配置
export MYSQL_HOME=${MYSQL_INSTALL_DIR}

# 确保 PATH 中不会重复添加 MySQL 路径
if [[ ":\$PATH:" != *":\$MYSQL_HOME/bin:"* ]]; then
    export PATH=\$PATH:\$MYSQL_HOME/bin
fi
EOF

    if [ $? -eq 0 ]; then
        print_success "MySQL 环境变量已设置"
        # 刷新当前会话的环境变量
        source "$env_file"
        print_success "环境变量已刷新"
    else
        print_error "环境变量配置失败"
        exit 1
    fi
}

mysql_install_setup_service() {
    print_section "配置系统服务"
    
    print_step "创建 systemd 服务文件..."
    cat > /etc/systemd/system/mysql.service <<EOF
[Unit]
Description=MySQL Server
Documentation=man:mysqld(8)
Documentation=http://dev.mysql.com/doc/refman/en/using-systemd.html
After=network.target
After=syslog.target

[Service]
Type=notify
User=${MYSQL_USER}
Group=${MYSQL_GROUP}
ExecStart=${MYSQL_INSTALL_DIR}/bin/mysqld --defaults-file=${MYSQL_CONF_DIR}/my.cnf
ExecStop=${MYSQL_INSTALL_DIR}/bin/mysqladmin shutdown
TimeoutSec=infinity
Restart=on-failure
RestartSec=5
LimitNOFILE=infinity
LimitMEMLOCK=infinity

[Install]
WantedBy=multi-user.target
EOF

    print_step "重载 systemd 配置..."
    systemctl daemon-reload
    
    print_step "启用 MySQL 服务..."
    systemctl enable mysql
    
    print_step "启动 MySQL 服务..."
    systemctl start mysql
    
    print_success "系统服务配置完成"
}

mysql_install_verify() {
    print_section "验证 MySQL 安装"
    
    print_step "检查安装目录..."
    if [ ! -d "$MYSQL_INSTALL_DIR" ]; then
        print_error "MySQL 安装目录不存在"
        exit 1
    fi

    print_step "检查服务状态..."
    if ! systemctl is-active mysql >/dev/null 2>&1; then
        print_error "MySQL 服务未正常运行"
        exit 1
    fi
    print_success "MySQL 服务运行正常"

    print_step "验证数据库连接..."
    if ! mysql -uroot -p"$MYSQL_ROOT_PASSWORD" -e "SELECT VERSION();" >/dev/null 2>&1; then
        print_error "无法连接到 MySQL 服务器"
        exit 1
    fi
    print_success "数据库连接正常"

    print_success "MySQL 安装验证完成"
}

mysql_install_finish() {
    print_section "完成 MySQL 安装"
    
    # 清理临时文件
    print_step "清理临时文件..."
    rm -rf "$MYSQL_TMP_DIR"/*
    print_success "临时文件清理完成"

    # 打印安装信息
    print_info "MySQL 安装信息："
    print_info "  版本: $MYSQL_VERSION"
    print_info "  安装目录: $MYSQL_INSTALL_DIR"
    print_info "  配置文件: $MYSQL_CONF_DIR/my.cnf"
    print_info "  数据目录: $MYSQL_DATA_DIR"
    print_info "  日志目录: $MYSQL_LOG_DIR"
    print_info "  Root 密码: $MYSQL_ROOT_PASSWORD"

    # 打印使用说明
    print_info "使用说明："
    print_info "  1. 启动服务: systemctl start mysql"
    print_info "  2. 停止服务: systemctl stop mysql"
    print_info "  3. 重启服务: systemctl restart mysql"
    print_info "  4. 查看状态: systemctl status mysql"
    print_info "  5. 连接数据库: mysql -uroot -p'$MYSQL_ROOT_PASSWORD'"

    print_success "MySQL 安装完成！"
}

# MySQL 主安装函数
mysql_install() {
    print_section "开始安装 MySQL"
    
    # 1. 前置检查
    mysql_common_check_dependencies
    mysql_common_check_disk_space
    mysql_install_select_version
    
    # 2. 清理环境（使用统一的清理函数）
    mysql_common_cleanup
    
    # 3. 准备安装环境
    mysql_install_prepare_directories
    mysql_install_create_user
    
    # 4. 下载和编译
    mysql_install_download_package
    mysql_install_download_boost
    mysql_install_compile
    
    # 5. 基础配置
    mysql_install_configure
    mysql_install_configure_env
    mysql_install_setup_service
    
    # 6. 初始化和启动
    mysql_install_initialize
    mysql_install_start_service
    mysql_install_set_password
    
    # 7. 安全配置
    mysql_install_configure_cron
    mysql_install_configure_firewall
    
    # 8. 验证和完成
    mysql_install_verify
    mysql_install_finish
}

# ==============================================
# MySQL 卸载相关函数
# ==============================================
mysql_uninstall() {
    print_section "开始卸载 MySQL"
    mysql_common_cleanup
    print_success "MySQL 已完全卸载！"
}

# ==============================================
# MySQL 管理函数
# ==============================================
manage_mysql() {
    while true; do
        print_section "MySQL 管理"
        print_info "请选择操作："
        print_info "1) 安装 MySQL"
        print_info "2) 卸载 MySQL"
        print_info "3) 返回主菜单"
        
        read -p "[$(date '+%Y-%m-%d %H:%M:%S')] [INPUT] - 请输入选项 [1-3]: " choice
        
        case $choice in
            1)
                mysql_install
                break
                ;;
            2)
                mysql_uninstall
                break
                ;;
            3)
                return 0
                ;;
            *)
                print_error "无效的选择"
                continue
                ;;
        esac
    done
}

# ==============================================
# 主函数
# ==============================================
main() {
    # 检查是否有 root 权限
    if [ "$EUID" -ne 0 ]; then
        print_error "此脚本需要 root 权限，请以 root 用户运行"
        exit 1
    fi
    
    manage_mysql
}

# 执行主程序
main