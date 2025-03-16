#!/bin/bash

# ==============================================
# HarborKod 软件安装管理工具
# 作者: harborkod
# 版本: 1.0.0
# ==============================================

# 命名规范说明
# ==============================================
# 1. 通用函数命名规范：
#    - 日志和输出相关函数：print_xxx
#    - 菜单管理相关函数：manage_xxx, select_xxx
#
# 2. 软件相关函数命名规范：
#    - 通用函数：{软件前缀}_common_xxx
#      例如：jdk_common_cleanup_path, jdk_common_check_dependencies
#
#    - 安装相关函数：{软件前缀}_install_xxx
#      例如：jdk_install_download_package, jdk_install_configure_env
#
#    - 卸载相关函数：{软件前缀}_uninstall_xxx
#      例如：jdk_uninstall_remove_env_files, jdk_uninstall_cleanup_env_vars
#
# 3. 软件前缀说明：
#    - JDK 相关：jdk_
#    - Maven 相关：mvn_
#    - MySQL 相关：mysql_
# ==============================================


# 1. 全局配置和变量
# ==============================================
# 是否开启调试模式 (true/false)
ENABLE_DEBUG=false

# 日志级别定义
LOG_DEBUG="DEBUG"
LOG_INFO="INFO"
LOG_WARN="WARN"
LOG_ERROR="ERROR"
LOG_SUCCESS="SUCCESS"

# 颜色代码
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

# 通用目录配置
DOWNLOAD_BASE_DIR="/opt"

# ==============================================
# JAVA 相关变量
# ==============================================
JDK_VERSION="8u421"
JDK_SOURCE_URL="https://harborkod.oss-rg-china-mainland.aliyuncs.com/arch/java/jdk-8u421-linux-x64.tar.gz"
JDK_INSTALL_DIR="/usr/local/jdk-${JDK_VERSION}"

# ==============================================
# MAVEN 相关变量
# ==============================================
MVN_VERSION="3.8.7"
MVN_USER="maven"
MVN_GROUP="maven"
MVN_SOURCE_URL="https://harborkod.oss-rg-china-mainland.aliyuncs.com/arch/maven/apache-maven-${MVN_VERSION}-bin.tar.gz"
MVN_INSTALL_DIR="/usr/local/apache-maven-${MVN_VERSION}"
MVN_LOCAL_REPO="/repo"



# ==============================================
# REDIS 相关变量
# ==============================================
REDIS_VERSION="6.2.9"
REDIS_USER="redis"
REDIS_GROUP="redis"
REDIS_PASSWORD="harborKod@redis@admin"
REDIS_SOURCE_URL="https://mirrors.huaweicloud.com/redis/redis-${REDIS_VERSION}.tar.gz"

# 标准目录结构
REDIS_INSTALL_DIR="/usr/local/redis"                # 程序安装目录
REDIS_CONF_DIR="/etc/redis"                         # 配置文件目录
REDIS_LOG_DIR="/var/log/redis"                      # 日志目录
REDIS_DATA_DIR="/var/lib/redis"                     # 数据目录
REDIS_SRC_DIR="/usr/local/src/redis-${REDIS_VERSION}"  # 源码目录




# ==============================================
# MySQL 相关变量
# ==============================================
MYSQL_USER="mysql"
MYSQL_GROUP="mysql"
MYSQL_ROOT_PASSWORD="harborKod@mysql@admin"
MYSQL_VERSION="5.7.37"
MYSQL_SOURCE_URL="https://harborkod.oss-rg-china-mainland.aliyuncs.com/arch/mysql/mysql-5.7.37.tar.gz"

# 标准目录结构
MYSQL_INSTALL_DIR="/usr/local/mysql"                # 程序安装目录
MYSQL_CONF_DIR="/etc/mysql"                         # 配置文件目录
MYSQL_LOG_DIR="/var/log/mysql"                      # 日志目录
MYSQL_BINLOG_DIR="/var/log/mysql/binlog"            # 二进制日志目录
MYSQL_RELAYLOG_DIR="/var/log/mysql/relaylog"        # 中继日志目录
MYSQL_DATA_DIR="/var/lib/mysql"                     # 数据目录
MYSQL_BACKUP_DIR="/var/backup/mysql"                # 备份目录
MYSQL_TMP_DIR="/var/tmp/mysql"                      # 临时文件目录
MYSQL_PID_DIR="/run/mysql"                          # pid文件目录
MYSQL_SRC_DIR="/usr/local/src/mysql-${MYSQL_VERSION}"  # 源码目录

# Boost 相关变量
MYSQL_BOOST_VERSION="1_59_0"
MYSQL_BOOST_SOURCE_URL="https://harborkod.oss-rg-china-mainland.aliyuncs.com/arch/mysql/boost_1_59_0.tar.gz"
MYSQL_BOOST_INSTALL_DIR="/usr/local/boost"

# ==============================================
# ZOOKEEPER 相关变量
# ==============================================
ZOOKEEPER_VERSION="3.7.1"
ZOOKEEPER_USER="zookeeper"
ZOOKEEPER_GROUP="zookeeper"
ZOOKEEPER_SOURCE_URL="https://harborkod.oss-rg-china-mainland.aliyuncs.com/arch/zookeeper/apache-zookeeper-${ZOOKEEPER_VERSION}-bin.tar.gz"

# 标准目录结构
ZOOKEEPER_INSTALL_DIR="/usr/local/zookeeper"        # 程序安装目录
ZOOKEEPER_CONF_DIR="/etc/zookeeper"                 # 配置文件目录
ZOOKEEPER_LOG_DIR="/var/log/zookeeper"              # 日志目录
ZOOKEEPER_DATA_DIR="/var/lib/zookeeper"             # 数据目录
ZOOKEEPER_PID_DIR="/run/zookeeper"                  # PID文件目录
ZOOKEEPER_PORT="2181"                               # 服务端口

# 安全配置
ZOOKEEPER_ENABLE_AUTH=true                          # 是否启用认证
ZOOKEEPER_SUPER_USER="zookeeper"                    # 超级用户
ZOOKEEPER_SUPER_PASSWORD="harborKod@zookeeper@admin" # 超级用户密码

# ==============================================
# KAFKA 相关变量
# ==============================================
KAFKA_VERSION="2.8.1"
KAFKA_SCALA_VERSION="2.13"
KAFKA_FULL_VERSION="${KAFKA_SCALA_VERSION}-${KAFKA_VERSION}"
KAFKA_USER="kafka"
KAFKA_GROUP="kafka" 
KAFKA_SOURCE_URL="https://archive.apache.org/dist/kafka/${KAFKA_VERSION}/kafka_${KAFKA_FULL_VERSION}.tgz"

# 标准目录结构
KAFKA_INSTALL_DIR="/usr/local/kafka"                # 程序安装目录
KAFKA_CONF_DIR="/etc/kafka"                         # 配置文件目录
KAFKA_LOG_DIR="/var/log/kafka"                      # 日志目录
KAFKA_DATA_DIR="/var/lib/kafka"                     # 数据目录
KAFKA_PID_DIR="/run/kafka"                          # PID文件目录

# 安全配置
KAFKA_ENABLE_AUTH=true                              # 是否启用认证
KAFKA_ADMIN_USER="admin"                            # 管理员用户
KAFKA_ADMIN_PASSWORD="harborKod@kafka@admin"        # 管理员密码





# ==============================================
# 日志输出函数
print_log() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    case "$level" in
        "$LOG_DEBUG")
            if [ "$ENABLE_DEBUG" = "true" ]; then
                echo -e "${BLUE}[$timestamp] [$level] - $message${NC}"
            fi
            ;;
        "$LOG_INFO")
            echo -e "${BLUE}[$timestamp] [$level] - $message${NC}"
            ;;
        "$LOG_WARN")
            echo -e "${YELLOW}[$timestamp] [$level] - $message${NC}"
            ;;
        "$LOG_ERROR")
            echo -e "${RED}[$timestamp] [$level] - $message${NC}"
            ;;
        "$LOG_SUCCESS")
            echo -e "${GREEN}[$timestamp] [$level] - $message${NC}"
            ;;
    esac
}

# 各种日志级别的快捷函数
print_debug() {
    local message="$1"
    print_log "$LOG_DEBUG" "$message"
}

print_info() {
    local message="$1"
    print_log "$LOG_INFO" "$message"
}

print_warning() {
    local message="$1"
    print_log "$LOG_WARN" "$message"
}

print_error() {
    local message="$1"
    print_log "$LOG_ERROR" "$message"
}

print_success() {
    local message="$1"
    print_log "$LOG_SUCCESS" "$message"
}

# 步骤提示函数
print_step() {
    local message="$1"
    print_info "执行步骤: $message"
}

# 如果开启了调试模式，打印初始环境信息
if [ "$ENABLE_DEBUG" = "true" ]; then
    print_debug "脚本开始执行"
    print_debug "调试模式已开启"
    print_debug "PATH: $PATH"
    print_debug "JAVA_HOME: $JAVA_HOME"
    print_debug "当前目录: $(pwd)"
fi


# 2. 通用函数
# ======================
# 日志和输出相关函数
print_header() {
    local total_width=60  # 与 print_section 保持一致的宽度

    echo ""
    echo -e "${BLUE}┌──────────────────────────────────────────────────────────┐${NC}"
    printf "%*s%s%*s\n" 15 "" "HarborKod 软件安装管理工具" 15 ""
    printf "%*s%s%*s\n" 24 "" "作者: harborkod" 23 ""
    printf "%*s%s%*s\n" 24 "" "版本: 1.0.0" 24 ""
    echo -e "${BLUE}└──────────────────────────────────────────────────────────┘${NC}"
    echo ""
}

# 计算字符串显示宽度的函数
get_string_width() {
    local input="$1"
    local width=0
    local char

    for (( i=0; i<${#input}; i++ )); do
        char="${input:$i:1}"
        if [[ "$char" =~ [[:print:]] ]]; then
            if [[ "$char" =~ [\x80-\xff] ]]; then
                # 中文字符占用 2 个宽度
                width=$((width + 2))
                # 跳过中文字符的第二个字节
                i=$((i + 2))
            else
                # ASCII 字符占用 1 个宽度
                width=$((width + 1))
            fi
        fi
    done
    echo "$width"
}

print_section() {
    local title="$1"
    local total_width=60
    local title_width=$(get_string_width "$title")
    local padding=$(( (total_width - title_width) / 2 ))
    local extra_space=$(( (total_width - title_width) % 2 ))

    print_info ""
    print_info "┌──────────────────────────────────────────────────────────┐"
    print_info "$(printf "%*s%s%*s" $padding "" "$title" $((padding + extra_space)) "")"
    print_info "└──────────────────────────────────────────────────────────┘"
}


# ==============================================
# ZooKeeper 相关函数
# ==============================================

# ZooKeeper 通用函数
zookeeper_common_check_dependencies() {
    print_section "检查 ZooKeeper 安装依赖"

    # 检查 Java 是否已安装
    if ! command -v java >/dev/null 2>&1; then
        print_error "未检测到 JDK，ZooKeeper 依赖 JDK 环境"
        print_info "请先安装 JDK"
        exit 1
    fi

    # 获取 Java 版本
    java_version=$(java -version 2>&1 | awk -F '"' '/version/ {print $2}')
    print_info "Java 版本: $java_version"

    # 检查必要的工具
    for cmd in wget tar; do
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
        fi
    done
}

zookeeper_common_check_processes() {
    print_section "检查 ZooKeeper 进程"
    print_step "检查是否有正在运行的 ZooKeeper 进程..."
    
    # 通过端口和进程名两种方式检查
    local zk_pid=$(lsof -t -i:${ZOOKEEPER_PORT} 2>/dev/null)
    if [ -n "$zk_pid" ]; then
        print_warning "检测到占用 ${ZOOKEEPER_PORT} 端口的进程 (PID: $zk_pid)"
        read -p "[$(date '+%Y-%m-%d %H:%M:%S')] [INPUT] - 是否终止该进程? (y/n): " terminate
        if [ "$terminate" = "y" ] || [ "$terminate" = "Y" ]; then
            kill -15 $zk_pid
            sleep 2
            if kill -0 $zk_pid 2>/dev/null; then
                kill -9 $zk_pid
            fi
            print_success "端口占用进程已终止"
        else
            print_error "端口 ${ZOOKEEPER_PORT} 被占用，无法继续安装"
            exit 1
        fi
    fi

    # 检查 QuorumPeerMain 进程 (ZooKeeper 主类)
    local zk_java_pid=$(ps -ef | grep QuorumPeerMain | grep -v grep | awk '{print $2}')
    if [ -n "$zk_java_pid" ]; then
        print_warning "检测到正在运行的 ZooKeeper Java 进程 (PID: $zk_java_pid)"
        read -p "[$(date '+%Y-%m-%d %H:%M:%S')] [INPUT] - 是否终止该进程? (y/n): " terminate
        if [ "$terminate" = "y" ] || [ "$terminate" = "Y" ]; then
            kill -15 $zk_java_pid
            sleep 2
            if kill -0 $zk_java_pid 2>/dev/null; then
                kill -9 $zk_java_pid
            fi
            print_success "ZooKeeper 进程已终止"
        else
            print_warning "ZooKeeper 进程将继续运行，可能影响安装"
        fi
    else
        print_info "未检测到运行中的 ZooKeeper 进程"
    fi
}

zookeeper_install_cleanup_previous() {
    print_section "清理历史数据"
    
    # 停止可能运行的 ZooKeeper 服务
    if systemctl is-active zookeeper >/dev/null 2>&1; then
        print_step "停止 ZooKeeper 服务..."
        systemctl stop zookeeper
        systemctl disable zookeeper
        print_success "ZooKeeper 服务已停止并禁用"
    fi
    
    # 删除旧的 ZooKeeper 安装
    if [ -d "$ZOOKEEPER_INSTALL_DIR" ]; then
        print_step "删除旧的 ZooKeeper 安装目录..."
        rm -rf "$ZOOKEEPER_INSTALL_DIR"
        print_success "旧的安装目录已删除"
    fi
    
    # 删除其他目录和文件
    local dirs=("$ZOOKEEPER_CONF_DIR" "$ZOOKEEPER_DATA_DIR" "$ZOOKEEPER_LOG_DIR" "$ZOOKEEPER_PID_DIR")
    for dir in "${dirs[@]}"; do
        if [ -d "$dir" ]; then
            print_step "删除目录: $dir"
            rm -rf "$dir"
            print_success "目录已删除: $dir"
        fi
    done

    # 删除 systemd 服务文件
    if [ -f "/etc/systemd/system/zookeeper.service" ]; then
        print_step "删除 systemd 服务文件..."
        rm -f "/etc/systemd/system/zookeeper.service"
        systemctl daemon-reload
        print_success "服务文件已删除"
    fi
    
    # 删除环境变量文件
    if [ -f "/etc/profile.d/zookeeper.sh" ]; then
        print_step "删除环境变量文件..."
        rm -f "/etc/profile.d/zookeeper.sh"
        print_success "环境变量文件已删除"
    fi
    
    # 清理临时下载文件
    print_step "清理临时下载文件..."
    rm -f "/opt/apache-zookeeper-*.tar.gz"
    print_success "临时文件清理完成"
}

zookeeper_install_download_package() {
    print_section "下载 ZooKeeper 安装包"
    
    local download_dir="/opt"
    local package_name="apache-zookeeper-${ZOOKEEPER_VERSION}-bin.tar.gz"
    local download_path="${download_dir}/${package_name}"
    
    print_step "检查下载目录..."
    if [ ! -d "$download_dir" ]; then
        mkdir -p "$download_dir"
    fi
    
    # 如果已经存在下载文件，询问是否重新下载
    if [ -f "$download_path" ]; then
        print_warning "发现已下载的 ZooKeeper 安装包"
        read -p "[$(date '+%Y-%m-%d %H:%M:%S')] [INPUT] - 是否重新下载? (y/n): " redownload
        if [ "$redownload" = "y" ] || [ "$redownload" = "Y" ]; then
            rm -f "$download_path"
        else
            print_info "使用已下载的安装包"
            return 0
        fi
    fi
    
    print_step "开始下载 ZooKeeper ${ZOOKEEPER_VERSION}..."
    if ! wget --no-check-certificate \
            --progress=bar:force \
            -O "$download_path" \
            "$ZOOKEEPER_SOURCE_URL"; then
        print_error "下载失败，请检查网络连接和下载地址"
        exit 1
    fi
    
    # 验证下载是否成功
    if [ ! -f "$download_path" ]; then
        print_error "下载文件不存在"
        exit 1
    fi
    
    if [ "$(stat -c%s "$download_path")" -lt 1000000 ]; then
        print_error "下载的文件大小异常，可能不是有效的安装包"
        exit 1
    fi
    
    print_success "ZooKeeper 安装包下载完成: $download_path"
}

zookeeper_install_prepare_directories() {
    print_section "准备 ZooKeeper 目录"
    
    # 创建用户和组
    print_step "创建用户和组..."
    if ! getent group "$ZOOKEEPER_GROUP" >/dev/null; then
        groupadd "$ZOOKEEPER_GROUP"
    fi
    
    if ! id "$ZOOKEEPER_USER" >/dev/null 2>&1; then
        useradd -r -g "$ZOOKEEPER_GROUP" -d "$ZOOKEEPER_DATA_DIR" -s /usr/sbin/nologin "$ZOOKEEPER_USER"
    fi
    
    # 创建必要的目录
    print_step "创建必要的目录..."
    local dirs=(
        "$ZOOKEEPER_INSTALL_DIR"
        "$ZOOKEEPER_CONF_DIR"
        "$ZOOKEEPER_LOG_DIR"
        "$ZOOKEEPER_DATA_DIR"
        "$ZOOKEEPER_PID_DIR"
    )
    
    for dir in "${dirs[@]}"; do
        if [ ! -d "$dir" ]; then
            mkdir -p "$dir"
        fi
    done
    
    # 设置目录权限 - 确保PID目录有正确的权限
    print_step "设置目录权限..."
    chown -R "$ZOOKEEPER_USER:$ZOOKEEPER_GROUP" "$ZOOKEEPER_DATA_DIR"
    chown -R "$ZOOKEEPER_USER:$ZOOKEEPER_GROUP" "$ZOOKEEPER_LOG_DIR"
    chown -R "$ZOOKEEPER_USER:$ZOOKEEPER_GROUP" "$ZOOKEEPER_PID_DIR"
    chmod 755 "$ZOOKEEPER_PID_DIR"  # 确保目录可访问
    
    # 创建myid文件 (单机模式使用1)
    print_step "创建 myid 文件..."
    echo "1" > "$ZOOKEEPER_DATA_DIR/myid"
    chown "$ZOOKEEPER_USER:$ZOOKEEPER_GROUP" "$ZOOKEEPER_DATA_DIR/myid"
    
    print_success "ZooKeeper 目录准备完成"
}

zookeeper_install_extract_package() {
    print_section "解压 ZooKeeper 安装包"
    
    local download_dir="/opt"
    local package_name="apache-zookeeper-${ZOOKEEPER_VERSION}-bin.tar.gz"
    local download_path="${download_dir}/${package_name}"
    
    print_step "解压安装包..."
    if ! tar -xzf "$download_path" -C "/tmp"; then
        print_error "解压失败"
        exit 1
    fi
    
    # 解压后的目录名
    local extracted_dir="/tmp/apache-zookeeper-${ZOOKEEPER_VERSION}-bin"
    
    # 确认解压目录存在
    if [ ! -d "$extracted_dir" ]; then
        print_error "解压后的目录不存在: $extracted_dir"
        exit 1
    fi
    
    print_step "复制文件到安装目录..."
    cp -rf "$extracted_dir"/* "$ZOOKEEPER_INSTALL_DIR"
    
    # 设置目录权限
    print_step "设置安装目录权限..."
    chown -R "$ZOOKEEPER_USER:$ZOOKEEPER_GROUP" "$ZOOKEEPER_INSTALL_DIR"
    
    # 清理临时文件
    print_step "清理临时文件..."
    rm -rf "$extracted_dir"
    
    print_success "ZooKeeper 安装包解压完成"
}

zookeeper_install_configure() {
    print_section "配置 ZooKeeper"
    
    print_step "创建基本配置文件..."
    
    # 创建基本配置文件
    local zoo_cfg="${ZOOKEEPER_CONF_DIR}/zoo.cfg"
    cat > "$zoo_cfg" << EOL
# ZooKeeper 基本配置
tickTime=2000
initLimit=10
syncLimit=5
dataDir=${ZOOKEEPER_DATA_DIR}
clientPort=${ZOOKEEPER_PORT}
maxClientCnxns=60
admin.enableServer=true
admin.serverPort=8080
4lw.commands.whitelist=*

# 日志配置
autopurge.snapRetainCount=10
autopurge.purgeInterval=24

# 性能优化
preAllocSize=65536
snapCount=100000
EOL

    # 如果启用认证，添加安全配置
    if [ "$ZOOKEEPER_ENABLE_AUTH" = true ]; then
        print_step "配置安全选项..."
        
        # 创建 JAAS 配置文件
        local jaas_file="${ZOOKEEPER_CONF_DIR}/jaas.conf"
        cat > "$jaas_file" << EOL
Server {
    org.apache.zookeeper.server.auth.DigestLoginModule required
    user_${ZOOKEEPER_SUPER_USER}="${ZOOKEEPER_SUPER_PASSWORD}";
};
EOL

        # 添加安全配置到 zoo.cfg
        cat >> "$zoo_cfg" << EOL

# 安全配置
authProvider.1=org.apache.zookeeper.server.auth.SASLAuthenticationProvider
requireClientAuthScheme=sasl
EOL

        # 设置权限
        chown "$ZOOKEEPER_USER:$ZOOKEEPER_GROUP" "$jaas_file"
        chmod 600 "$jaas_file"
    fi
    
    # 修改日志配置文件，确保使用.log扩展名
    print_step "创建日志配置文件..."
    cat > "${ZOOKEEPER_CONF_DIR}/log4j.properties" << EOL
zookeeper.root.logger=INFO, CONSOLE, ROLLINGFILE
zookeeper.console.threshold=INFO
zookeeper.log.dir=${ZOOKEEPER_LOG_DIR}
zookeeper.log.file=zookeeper.log
zookeeper.log.threshold=INFO
zookeeper.tracelog.dir=${ZOOKEEPER_LOG_DIR}
zookeeper.tracelog.file=zookeeper_trace.log

# 禁用.out日志文件
zookeeper.serverlog.enabled=false
zookeeper.serverlog.dir=${ZOOKEEPER_LOG_DIR}
zookeeper.serverlog.file=zookeeper_server.log

log4j.rootLogger=\${zookeeper.root.logger}

# Console appender
log4j.appender.CONSOLE=org.apache.log4j.ConsoleAppender
log4j.appender.CONSOLE.Threshold=\${zookeeper.console.threshold}
log4j.appender.CONSOLE.layout=org.apache.log4j.PatternLayout
log4j.appender.CONSOLE.layout.ConversionPattern=%d{ISO8601} [myid:%X{myid}] - %-5p [%t:%C{1}@%L] - %m%n

# Rolling file appender
log4j.appender.ROLLINGFILE=org.apache.log4j.RollingFileAppender
log4j.appender.ROLLINGFILE.Threshold=\${zookeeper.log.threshold}
log4j.appender.ROLLINGFILE.File=\${zookeeper.log.dir}/\${zookeeper.log.file}
log4j.appender.ROLLINGFILE.MaxFileSize=100MB
log4j.appender.ROLLINGFILE.MaxBackupIndex=10
log4j.appender.ROLLINGFILE.layout=org.apache.log4j.PatternLayout
log4j.appender.ROLLINGFILE.layout.ConversionPattern=%d{ISO8601} [myid:%X{myid}] - %-5p [%t:%C{1}@%L] - %m%n
EOL

    # 创建一个环境变量配置文件 - 使用ZooKeeper默认的变量和设置
    cat > "${ZOOKEEPER_CONF_DIR}/zookeeper-env.sh" << EOL
#!/bin/bash
ZOO_LOG4J_PROP="INFO,ROLLINGFILE"
ZOO_LOG_DIR="${ZOOKEEPER_LOG_DIR}"
ZOO_LOG_FILE="zookeeper.log"
# 使用默认PID目录路径
ZOO_PID_DIR="/run/zookeeper"
JVMFLAGS="-Dzookeeper.log.dir=\${ZOO_LOG_DIR} -Dzookeeper.log.file=\${ZOO_LOG_FILE} -Dzookeeper.root.logger=\${ZOO_LOG4J_PROP}"
EOL

    chmod +x "${ZOOKEEPER_CONF_DIR}/zookeeper-env.sh"
    chown "$ZOOKEEPER_USER:$ZOOKEEPER_GROUP" "${ZOOKEEPER_CONF_DIR}/zookeeper-env.sh"
    
    # 设置文件权限
    print_step "设置配置文件权限..."
    chown -R "$ZOOKEEPER_USER:$ZOOKEEPER_GROUP" "$ZOOKEEPER_CONF_DIR"
    chmod -R 750 "$ZOOKEEPER_CONF_DIR"
    
    print_success "ZooKeeper 配置完成"
}

zookeeper_install_setup_service() {
    print_section "设置 ZooKeeper 系统服务"
    
    # 创建服务文件
    print_step "创建 systemd 服务文件..."
    local service_file="/etc/systemd/system/zookeeper.service"
    cat > "$service_file" << EOL
[Unit]
Description=ZooKeeper Service
Documentation=https://zookeeper.apache.org
After=network.target

[Service]
Type=forking
User=${ZOOKEEPER_USER}
Group=${ZOOKEEPER_GROUP}
Environment="ZOO_LOG_DIR=${ZOOKEEPER_LOG_DIR}"
Environment="ZOOCFGDIR=${ZOOKEEPER_CONF_DIR}" 
Environment="ZOO_PID_DIR=/run/zookeeper"

PermissionsStartOnly=true
ExecStartPre=/bin/sh -c 'mkdir -p /run/zookeeper && rm -f /run/zookeeper/zookeeper_server.pid && touch /run/zookeeper/zookeeper_server.pid && chown -R ${ZOOKEEPER_USER}:${ZOOKEEPER_GROUP} /run/zookeeper'
ExecStart=${ZOOKEEPER_INSTALL_DIR}/bin/zkServer.sh start
ExecStartPost=/bin/sh -c 'pid=\$(pgrep -f org.apache.zookeeper.server.quorum.QuorumPeerMain | head -1); if [ -n "\$pid" ]; then echo \$pid > /run/zookeeper/zookeeper_server.pid; fi'
ExecStop=${ZOOKEEPER_INSTALL_DIR}/bin/zkServer.sh stop
WorkingDirectory=${ZOOKEEPER_INSTALL_DIR}
PIDFile=/run/zookeeper/zookeeper_server.pid

TimeoutSec=180
Restart=on-failure
RestartSec=30
LimitNOFILE=65536
RuntimeDirectory=zookeeper
RuntimeDirectoryMode=0755

[Install]
WantedBy=multi-user.target
EOL

    # 重新加载 systemd
    print_step "重新加载 systemd..."
    systemctl daemon-reload
    
    # 启用并启动服务
    print_step "启用 ZooKeeper 服务..."
    systemctl enable zookeeper
    
    print_step "启动 ZooKeeper 服务..."
    systemctl start zookeeper
    
    # 等待服务启动
    print_step "等待服务启动..."
    sleep 10
    
    # 通过检查进程来验证
    if pgrep -f "org.apache.zookeeper.server.quorum.QuorumPeerMain" > /dev/null; then
        print_success "ZooKeeper 服务已启动"
    else
        print_error "ZooKeeper 服务启动失败"
        print_info "请检查日志: journalctl -u zookeeper"
        exit 1
    fi
    
    print_success "ZooKeeper 系统服务设置完成"
}

zookeeper_install_create_client_guide() {
    print_section "创建 ZooKeeper 客户端连接指南"
    
    # 创建客户端指南目录
    print_step "创建客户端指南目录..."
    local guide_dir="${ZOOKEEPER_INSTALL_DIR}/client-guide"
    mkdir -p "$guide_dir"
    
    # 创建 README 文件
    print_step "创建连接指南文档..."
    local readme_file="${guide_dir}/README.md"
    
    cat > "$readme_file" << EOL
# ZooKeeper 客户端连接指南

## 基本信息
- ZooKeeper 版本: ${ZOOKEEPER_VERSION}
- 服务器地址: $(hostname -I | awk '{print $1}')
- 端口: ${ZOOKEEPER_PORT}
- 安装目录: ${ZOOKEEPER_INSTALL_DIR}

## 命令行连接
EOL

    # 根据是否启用安全认证添加不同的连接示例
    if [ "$ZOOKEEPER_ENABLE_AUTH" = true ]; then
        cat >> "$readme_file" << EOL
### 带认证连接
\`\`\`bash
# 使用内置客户端带认证连接
${ZOOKEEPER_INSTALL_DIR}/bin/zkCli.sh -server localhost:${ZOOKEEPER_PORT} -auth digest:${ZOOKEEPER_SUPER_USER}:${ZOOKEEPER_SUPER_PASSWORD}

# 远程服务器连接
${ZOOKEEPER_INSTALL_DIR}/bin/zkCli.sh -server your-server-ip:${ZOOKEEPER_PORT} -auth digest:${ZOOKEEPER_SUPER_USER}:${ZOOKEEPER_SUPER_PASSWORD}
\`\`\`

## JAAS 配置文件示例
创建一个名为 \`client-jaas.conf\` 的文件，内容如下:

\`\`\`
Client {
    org.apache.zookeeper.server.auth.DigestLoginModule required
    username="${ZOOKEEPER_SUPER_USER}"
    password="${ZOOKEEPER_SUPER_PASSWORD}";
};
\`\`\`

## Java 客户端连接示例
\`\`\`java
// Java 连接示例
Properties props = new Properties();
props.setProperty("zookeeper.sasl.client", "true");
props.setProperty("zookeeper.sasl.clientconfig", "Client");
System.setProperty("java.security.auth.login.config", "/path/to/client-jaas.conf");

ZooKeeper zk = new ZooKeeper("your-server-ip:${ZOOKEEPER_PORT}", 3000, watcher);
zk.addAuthInfo("digest", "${ZOOKEEPER_SUPER_USER}:${ZOOKEEPER_SUPER_PASSWORD}".getBytes());
\`\`\`
EOL
    else
        cat >> "$readme_file" << EOL
### 连接命令
\`\`\`bash
# 本地连接
${ZOOKEEPER_INSTALL_DIR}/bin/zkCli.sh -server localhost:${ZOOKEEPER_PORT}

# 远程服务器连接
${ZOOKEEPER_INSTALL_DIR}/bin/zkCli.sh -server your-server-ip:${ZOOKEEPER_PORT}
\`\`\`

## Java 客户端连接示例
\`\`\`java
// Java 连接示例
ZooKeeper zk = new ZooKeeper("your-server-ip:${ZOOKEEPER_PORT}", 3000, watcher);
\`\`\`
EOL
    fi
    
    cat >> "$readme_file" << EOL

## 常用操作命令
\`\`\`bash
# 列出根节点下的子节点
ls /

# 创建节点
create /my_node data

# 获取节点数据
get /my_node

# 修改节点数据
set /my_node new_data

# 删除节点
delete /my_node

# 递归删除节点及其子节点
deleteall /my_node

# 查看节点状态
stat /my_node
\`\`\`

## 测试连接
\`\`\`bash
${ZOOKEEPER_INSTALL_DIR}/bin/zkServer.sh status
\`\`\`
EOL

    # 创建测试连接脚本
    print_step "创建测试连接脚本..."
    local test_script="${guide_dir}/test-connection.sh"
    
    cat > "$test_script" << 'EOL'
#!/bin/bash
# ZooKeeper 连接测试脚本

# 服务器信息
ZK_SERVER="localhost"
ZK_PORT="2181"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 测试连接函数
test_connection() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] - 测试连接到 ZooKeeper 服务器 ${ZK_SERVER}:${ZK_PORT}...${NC}"
    
    # 尝试使用 ruok 命令测试
    local result=$(echo ruok | nc ${ZK_SERVER} ${ZK_PORT} 2>/dev/null)
    
    if [ "$result" == "imok" ]; then
        echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] [SUCCESS] - 连接测试成功!${NC}"
        return 0
    else
        echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] - 连接测试失败!${NC}"
        return 1
    fi
}

# 测试基本操作
test_operations() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] - 测试 ZooKeeper 基本操作...${NC}"
    
    # 获取 ZooKeeper 根节点列表
    local zkdir=$(dirname "$0")/../bin
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] - 尝试获取根节点列表...${NC}"
    ${zkdir}/zkCli.sh -server ${ZK_SERVER}:${ZK_PORT} ls / 2>&1 | grep -q "WatchedEvent"
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] [SUCCESS] - 基本操作测试成功!${NC}"
        return 0
    else
        echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] - 基本操作测试失败!${NC}"
        return 1
    fi
}

# 主函数
main() {
    echo -e "${BLUE}=== ZooKeeper 连接测试 ===${NC}"
    
    if test_connection; then
        test_operations
    else
        echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] [WARN] - 跳过操作测试${NC}"
        exit 1
    fi
    
    echo -e "${BLUE}=== 测试完成 ===${NC}"
}

# 执行主函数
main
EOL

    # 设置执行权限
    chmod +x "$test_script"
    
    # 替换端口
    sed -i "s/ZK_PORT=\"2181\"/ZK_PORT=\"${ZOOKEEPER_PORT}\"/" "$test_script"
    
    # 设置目录权限
    chown -R "$ZOOKEEPER_USER:$ZOOKEEPER_GROUP" "$guide_dir"
    chmod -R 755 "$guide_dir"
    
    print_success "ZooKeeper 客户端连接指南创建完成"
}

zookeeper_install_verify() {
    print_section "验证 ZooKeeper 安装"
    
    print_step "检查进程..."
    if ! pgrep -f "org.apache.zookeeper.server.quorum.QuorumPeerMain" > /dev/null; then
        print_error "ZooKeeper 进程未运行"
        exit 1
    fi
    
    print_step "检查端口..."
    if ! netstat -tuln | grep ":${ZOOKEEPER_PORT}" > /dev/null; then
        print_error "ZooKeeper 端口 ${ZOOKEEPER_PORT} 未监听"
        exit 1
    fi
    
    print_step "测试简单连接..."
    # 使用我们刚刚配置的环境变量确保脚本找到正确的配置文件
    if ! echo "ruok" | nc localhost ${ZOOKEEPER_PORT} 2>/dev/null | grep -q "imok"; then
        print_warning "ZooKeeper 4lw 连接测试失败，尝试另一种方式验证..."
        
        # 使用zkServer.sh status，并明确指定配置文件路径
        if ! ZOOCFGDIR=${ZOOKEEPER_CONF_DIR} ${ZOOKEEPER_INSTALL_DIR}/bin/zkServer.sh status; then
            print_error "ZooKeeper 连接测试失败"
            exit 1
        fi
    fi
    
    print_success "ZooKeeper 验证完成，服务运行正常"
}

zookeeper_install_finish() {
    print_section "ZooKeeper 安装完成"
    
    print_info "ZooKeeper 安装信息:"
    print_info "  版本: ${ZOOKEEPER_VERSION}"
    print_info "  安装目录: ${ZOOKEEPER_INSTALL_DIR}"
    print_info "  配置目录: ${ZOOKEEPER_CONF_DIR}"
    print_info "  数据目录: ${ZOOKEEPER_DATA_DIR}"
    print_info "  日志目录: ${ZOOKEEPER_LOG_DIR}"
    print_info "  服务状态: $(systemctl is-active zookeeper)"
    print_info "  端口: ${ZOOKEEPER_PORT}"
    
    if [ "$ZOOKEEPER_ENABLE_AUTH" = true ]; then
        print_info "  认证用户: ${ZOOKEEPER_SUPER_USER}"
        print_info "  认证密码: ${ZOOKEEPER_SUPER_PASSWORD}"
    fi
    
    print_info "服务控制命令:"
    print_info "  启动: systemctl start zookeeper"
    print_info "  停止: systemctl stop zookeeper"
    print_info "  重启: systemctl restart zookeeper"
    print_info "  状态: systemctl status zookeeper"
    
    print_info "客户端连接指南:"
    print_info "  ${ZOOKEEPER_INSTALL_DIR}/client-guide/README.md"
    
    print_success "ZooKeeper 安装成功完成"
}

zookeeper_install() {
    print_debug "开始 ZooKeeper 安装流程"
    
    # 记录开始时间
    local start_time=$(date +%s)
    
    # 执行安装步骤
    zookeeper_common_check_dependencies
    zookeeper_common_check_processes
    zookeeper_install_cleanup_previous
    zookeeper_install_download_package
    zookeeper_install_prepare_directories
    zookeeper_install_extract_package
    zookeeper_install_configure
    zookeeper_install_setup_service
    zookeeper_install_create_client_guide
    zookeeper_install_verify
    
    # 计算用时
    local end_time=$(date +%s)
    local installation_time=$((end_time - start_time))
    
    print_info "安装用时: ${installation_time} 秒"
    zookeeper_install_finish
}

zookeeper_uninstall_stop_service() {
    print_section "停止 ZooKeeper 服务"
    
    # 检查服务是否在运行
    if systemctl is-active zookeeper >/dev/null 2>&1; then
        print_step "停止 ZooKeeper 服务..."
        systemctl stop zookeeper
        systemctl disable zookeeper
        print_success "ZooKeeper 服务已停止并禁用"
    else
        print_info "ZooKeeper 服务未在运行"
    fi
    
    # 检查进程
    local zk_pid=$(pgrep -f "org.apache.zookeeper.server.quorum.QuorumPeerMain")
    if [ -n "$zk_pid" ]; then
        print_warning "发现 ZooKeeper 进程仍在运行，尝试终止..."
        kill -15 $zk_pid
        sleep 2
        if kill -0 $zk_pid 2>/dev/null; then
            print_warning "进程未响应 SIGTERM，使用 SIGKILL..."
            kill -9 $zk_pid
        fi
    fi
    
    # 移除服务文件
    if [ -f "/etc/systemd/system/zookeeper.service" ]; then
        print_step "移除服务文件..."
        rm -f "/etc/systemd/system/zookeeper.service"
        systemctl daemon-reload
        print_success "服务文件已移除"
    fi
}

zookeeper_uninstall_remove_files() {
    print_section "移除 ZooKeeper 文件"
    
    # 读取用户确认（除非静默模式）
    local confirm_remove="n"
    read -p "[$(date '+%Y-%m-%d %H:%M:%S')] [INPUT] - 是否删除 ZooKeeper 数据和日志文件? (y/n): " confirm_remove
    
    # 移除安装和配置目录
    print_step "移除安装目录和配置..."
    rm -rf "$ZOOKEEPER_INSTALL_DIR"
    rm -rf "$ZOOKEEPER_CONF_DIR"
    
    # 有条件地移除数据和日志目录
    if [ "$confirm_remove" = "y" ] || [ "$confirm_remove" = "Y" ]; then
        print_step "移除数据和日志目录..."
        rm -rf "$ZOOKEEPER_DATA_DIR"
        rm -rf "$ZOOKEEPER_LOG_DIR"
        rm -rf "$ZOOKEEPER_PID_DIR"
        print_success "数据和日志目录已移除"
    else
        print_info "保留数据和日志目录"
    fi
    
    print_success "ZooKeeper 文件移除完成"
}

zookeeper_uninstall_remove_env_files() {
    print_section "移除 ZooKeeper 环境变量"
    
    # 移除环境变量文件
    if [ -f "/etc/profile.d/zookeeper.sh" ]; then
        print_step "移除环境变量文件..."
        rm -f "/etc/profile.d/zookeeper.sh"
        print_success "环境变量文件已移除"
    fi
    
    # 清理当前会话的环境变量
    print_step "清理当前会话环境变量..."
    unset ZOOKEEPER_HOME
    unset ZOO_LOG_DIR
    unset ZOOCFGDIR
    unset JVMFLAGS
    
    # 清理 PATH
    if [[ "$PATH" == *"zookeeper"* ]]; then
        export PATH=$(echo $PATH | tr ':' '\n' | grep -v "zookeeper" | tr '\n' ':' | sed 's/:$//')
    fi
    
    print_success "环境变量已清理"
}

zookeeper_uninstall_remove_user() {
    print_section "移除 ZooKeeper 用户和组"
    
    # 检查用户是否存在
    if id "$ZOOKEEPER_USER" >/dev/null 2>&1; then
        print_step "移除用户: ${ZOOKEEPER_USER}..."
        userdel -r "$ZOOKEEPER_USER" 2>/dev/null
        print_success "用户已移除"
    fi
    
    # 检查组是否存在
    if getent group "$ZOOKEEPER_GROUP" >/dev/null; then
        print_step "移除用户组: ${ZOOKEEPER_GROUP}..."
        groupdel "$ZOOKEEPER_GROUP" 2>/dev/null
        print_success "用户组已移除"
    fi
}

zookeeper_uninstall_finish() {
    print_section "ZooKeeper 卸载完成"
    print_success "ZooKeeper 已成功卸载"
}

zookeeper_uninstall() {
    print_section "卸载 ZooKeeper"
    
    print_warning "此操作将删除 ZooKeeper 及其配置"
    read -p "[$(date '+%Y-%m-%d %H:%M:%S')] [INPUT] - 确定要卸载 ZooKeeper 吗? (y/n): " confirm
    
    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        print_info "卸载已取消"
        return 0
    fi
    
    zookeeper_uninstall_stop_service
    zookeeper_uninstall_remove_files
    zookeeper_uninstall_remove_env_files
    zookeeper_uninstall_remove_user
    zookeeper_uninstall_finish
}



# 7. 菜单管理函数
# ======================
manage_java() {
    print_section "JDK 管理"
    print_info "请选择操作:"
    print_info "1) 安装 JDK"
    print_info "2) 卸载 JDK"
    print_info "3) 返回主菜单"

    read -p "[$(date '+%Y-%m-%d %H:%M:%S')] [INPUT] - 请输入选项 [1-3]: " choice

    case $choice in
        1) jdk_install ;;
        2) jdk_uninstall ;;
        3) main ;;
        *) print_error "无效的选择"; exit 1 ;;
    esac
}

manage_maven() {
    print_section "Maven 管理"
    print_info "请选择操作:"
    print_info "1) 安装 Maven"
    print_info "2) 卸载 Maven"
    print_info "3) 返回主菜单"

    read -p "[$(date '+%Y-%m-%d %H:%M:%S')] [INPUT] - 请输入选项 [1-3]: " choice

    case $choice in
        1) mvn_install ;;
        2) mvn_uninstall ;;
        3) main ;;
        *) print_error "无效的选择"; exit 1 ;;
    esac
}

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

manage_zookeeper() {
    print_section "ZooKeeper 管理"
    
    while true; do
        print_info "1) 安装 ZooKeeper"
        print_info "2) 卸载 ZooKeeper"
        print_info "3) 返回主菜单"

        read -p "[$(date '+%Y-%m-%d %H:%M:%S')] [INPUT] - 请输入选项 [1-3]: " choice

        case $choice in
            1)
                zookeeper_install
                ;;
            2)
                zookeeper_uninstall
                ;;
            3)
                return 0
                ;;
            *)
                print_error "无效的选择"
                ;;
        esac
    done
}

# CentOS 软件源更新相关函数
centos_repo_update() {
    print_section "更新 CentOS 软件源"

    # 检查系统版本
    if ! grep -qi "centos" /etc/redhat-release; then
        print_error "当前系统不是 CentOS，无法更新软件源"
        exit 1
    fi

    # 备份原有的 repo 文件
    print_step "备份原有软件源配置..."
    sudo mkdir -p /etc/yum.repos.d/backup
    sudo mv /etc/yum.repos.d/*.repo /etc/yum.repos.d/backup/ 2>/dev/null
    print_success "原有配置已备份到 /etc/yum.repos.d/backup/"

    # 下载新的 repo 文件
    print_step "下载阿里云 CentOS 软件源配置..."
    if ! curl -o /etc/yum.repos.d/CentOS-Base.repo https://mirrors.aliyun.com/repo/Centos-7.repo; then
        print_error "下载 CentOS-Base.repo 失败"
        exit 1
    fi
    print_success "CentOS Base 源配置完成"

    # 添加 EPEL 源
    print_step "下载阿里云 EPEL 源配置..."
    if ! curl -o /etc/yum.repos.d/epel.repo https://mirrors.aliyun.com/repo/epel-7.repo; then
        print_error "下载 epel.repo 失败"
        exit 1
    fi
    print_success "EPEL 源配置完成"

    # 清除缓存并更新
    print_step "清理并更新软件源缓存..."
    yum clean all
    rm -rf /var/cache/yum/*
    yum makecache
    print_success "软件源缓存已更新"

    # 验证源是否可用
    print_step "验证软件源可用性..."
    if ! yum repolist | grep -E "base|extras|updates|epel" > /dev/null; then
        print_error "软件源验证失败"
        exit 1
    fi

    print_success "CentOS 软件源已成功更新为阿里云镜像！"
}

# 添加系统依赖检查函数
check_system_dependencies() {
    print_section "检查系统依赖"

    # 检查 root 权限
    if [ "$EUID" -ne 0 ] && ! command -v sudo >/dev/null 2>&1; then
        print_error "此脚本需要 root 权限或 sudo 命令"
        exit 1
    fi

    # 定义依赖项及其对应的包名
    declare -A dependencies=(
        ["wget"]="wget"
        ["tar"]="tar"
        ["gcc"]="gcc"
        ["g++"]="gcc-c++"
        ["make"]="make"
        ["cmake"]="cmake"
        ["bison"]="bison"
        ["perl"]="perl"
        ["git"]="git"
        ["curl"]="curl"
        ["vim"]="vim"
        ["unzip"]="unzip"
        ["net-tools"]="net-tools"
        ["telnet"]="telnet"
    )

    # 检查每个依赖
    for cmd in "${!dependencies[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            print_warning "未检测到 $cmd 命令，正在安装..."
            if command -v yum >/dev/null 2>&1; then
                sudo yum install -y "${dependencies[$cmd]}"
            elif command -v apt-get >/dev/null 2>&1; then
                sudo apt-get update
                sudo apt-get install -y "${dependencies[$cmd]}"
            elif command -v dnf >/dev/null 2>&1; then
                sudo dnf install -y "${dependencies[$cmd]}"
            else
                print_error "无法找到包管理器（yum/apt-get/dnf），请手动安装 ${dependencies[$cmd]}"
                exit 1
            fi
            if [ $? -eq 0 ]; then
                print_success "${dependencies[$cmd]} 安装完成"
            else
                print_error "${dependencies[$cmd]} 安装失败"
                exit 1
            fi
        else
            print_success "$cmd 已安装"
        fi
    done

    print_success "所有系统依赖检查完成"

    # 直接返回主菜单
    select_software
}

# 更新主菜单函数
select_software() {
    print_info "Please select an option:"
    print_info "1) Update CentOS repositories"
    print_info "2) Check and install system dependencies"
    print_info "3) Java (JDK)"
    print_info "4) Maven"
    print_info "5) Redis"
    print_info "6) ZooKeeper"
    print_info "7) MySQL"
    print_info "8) Exit"

    read -p "[$(date '+%Y-%m-%d %H:%M:%S')] [INPUT] - Please enter an option [1-8]: " software_choice

    case $software_choice in
        1) centos_repo_update ;;
        2) check_system_dependencies ;;
        3) manage_java ;;
        4) manage_maven ;;
        5) manage_redis ;;
        6) manage_zookeeper ;;
        7) manage_mysql ;;
        8)
            print_info "Thank you for using this script. Goodbye!"
            exit 0
            ;;
        *) print_error "Invalid option" ;;
    esac
}


# 8. 主函数
# ======================
main() {
    print_info "HarborKod Software Shell Manager"
    print_info "Author: harborkod"
    print_info "Version: 1.0.4"
    print_info "GitHub: https://github.com/harborkod"
    select_software
}

# 执行主函数
main