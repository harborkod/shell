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




# 3. JDK 相关函数
# ======================

# JDK 通用函数
jdk_common_cleanup_path() {
    # 保存原始 IFS
    local OIFS="$IFS"
    IFS=':'

    # 将 PATH 转换为数组
    local -a paths=($PATH)
    declare -A unique_paths
    local new_path=""

    for p in "${paths[@]}"; do
        if [[ "$p" != *"java"* ]] && [[ "$p" != *"jdk"* ]]; then
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

jdk_common_check_dependencies() {
    print_section "检查 JDK 安装依赖"
    if [ "$EUID" -ne 0 ] && ! command -v sudo >/dev/null 2>&1; then
        print_error "此脚本需要 root 权限或 sudo 命令"
        exit 1
    fi

    for cmd in tar wget unzip; do
        if ! command -v $cmd >/dev/null 2>&1; then
            print_warning "未检测到 $cmd 命令，正在安装 $cmd..."
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

jdk_common_check_processes() {
    print_section "检查运行中的 Java 进程"
    print_step "检查 Java 进程..."
    local java_processes=$(ps -ef | grep java | grep -v grep | grep -v $$ | awk '{print $2}')
    if [ -n "$java_processes" ]; then
        print_warning "检测到正在运行的 Java 进程"
        for pid in $java_processes; do
            if kill -0 $pid 2>/dev/null; then
                print_step "正在终止进程 PID: $pid"
                kill -15 $pid 2>/dev/null || kill -9 $pid 2>/dev/null
                sleep 1
            fi
        done
        print_success "Java 进程已终止"
    else
        print_info "没有检测到运行中的 Java 进程"
    fi
}

# JDK 安装相关函数
jdk_install_check_existing() {
    print_section "检查现有 JDK 安装"
    if command -v java >/dev/null 2>&1; then
        print_info "检测到已安装的 Java 版本："
        java -version 2>&1

        if java -version 2>&1 | grep -i "openjdk" >/dev/null; then
            print_warning "检测到系统已安装 OpenJDK"
            read -p "[$(date '+%Y-%m-%d %H:%M:%S')] [INPUT] - 是否要卸载现有的 OpenJDK 后继续安装？(y/n): " remove_choice
            if [ "$remove_choice" = "y" ] || [ "$remove_choice" = "Y" ]; then
                print_step "正在卸载 OpenJDK..."
                jdk_uninstall_remove_system_jdk
            else
                print_info "用户选择保留现有 Java 安装"
                exit 0
            fi
        else
            print_warning "检测到已安装其他版本的 Java"
            read -p "[$(date '+%Y-%m-%d %H:%M:%S')] [INPUT] - 是否继续安装新版本？(y/n): " continue_choice
            if [ "$continue_choice" != "y" ] && [ "$continue_choice" != "Y" ]; then
                print_info "用户选择不继续安装"
                exit 0
            fi
        fi
    else
        print_info "未检测到已安装的 Java"
    fi
}

jdk_install_select_version() {
    print_section "选择 JDK 版本"

    # JDK 版本信息直接定义在函数中
    local JDK_INFO=(
        "Oracle JDK 8u421:jdk-8u421:https://harborkod.oss-rg-china-mainland.aliyuncs.com/arch/java/jdk-8u421-linux-x64.tar.gz"
        "OpenJDK 11.0.2:openjdk-11.0.2:https://mirrors.huaweicloud.com/openjdk/11.0.2/openjdk-11.0.2_linux-x64_bin.tar.gz"
        "OpenJDK 17.0.2:openjdk-17.0.2:https://mirrors.huaweicloud.com/openjdk/17.0.2/openjdk-17.0.2_linux-x64_bin.tar.gz"
    )

    # 显示选项
    local i=1
    for version in "${JDK_INFO[@]}"; do
        local name=$(echo "$version" | cut -d: -f1)
        print_info "$i) $name"
        ((i++))
    done

    read -p "[$(date '+%Y-%m-%d %H:%M:%S')] [INPUT] - 请输入选项 [1-${#JDK_INFO[@]}]: " choice

    if [[ ! "$choice" =~ ^[1-${#JDK_INFO[@]}]$ ]]; then
        print_error "无效的选择"
        exit 1
    fi

    # 获取选择的版本信息
    local selected="${JDK_INFO[$((choice-1))]}"

    # 添加调试信息
    print_debug "原始选择信息: $selected"

    # 使用 IFS 来分割字符串
    local IFS=":"
    read -r name jdk_version download_url <<< "$selected"

    # 设置安装目录
    JDK_INSTALL_DIR="/usr/local/$jdk_version"

    # 添加调试信息
    print_debug "选择的版本信息: $selected"
    print_debug "名称: $name"
    print_debug "解析后的版本: $jdk_version"
    print_debug "解析后的下载URL: $download_url"
    print_debug "解析后的安装目录: $JDK_INSTALL_DIR"

    print_success "已选择: $jdk_version"
}

jdk_install_cleanup_previous() {
    print_section "清理历史数据"
    DOWNLOAD_BASE_DIR="/opt"
    jdk_package="$DOWNLOAD_BASE_DIR/$(basename $download_url)"

    if [ -f "$jdk_package" ]; then
        print_step "清理已有安装包: $jdk_package"
        rm -f "$jdk_package"
        print_success "安装包清理完成"
    fi

    if [ -d "$JDK_INSTALL_DIR" ]; then
        print_step "清理已有安装目录: $JDK_INSTALL_DIR"
        rm -rf "$JDK_INSTALL_DIR"
        print_success "安装目录清理完成"
    fi

    env_file="/etc/profile.d/java_${jdk_version}.sh"
    if [ -f "$env_file" ]; then
        print_step "备份环境变量配置文件: $env_file"
        sudo mv "$env_file" "${env_file}.bak_$(date +%Y%m%d%H%M%S)"
        print_success "配置文件备份完成"
    fi

    jdk_cleanup_alternatives
}

jdk_cleanup_alternatives() {
    print_section "清理 Alternatives 配置"
    if command -v update-alternatives >/dev/null 2>&1; then
        ALTERNATIVES_CMD="update-alternatives"
    elif command -v alternatives >/dev/null 2>&1; then
        ALTERNATIVES_CMD="alternatives"
    else
        print_warning "未找到 alternatives 命令，跳过清理"
        return
    fi

    if [ -x "$JDK_INSTALL_DIR/bin/java" ]; then
        print_step "移除 java alternatives 配置"
        sudo $ALTERNATIVES_CMD --remove java "$JDK_INSTALL_DIR/bin/java"
        print_success "Java alternatives 已清理"
    fi

    if [ -x "$JDK_INSTALL_DIR/bin/javac" ]; then
        print_step "移除 javac alternatives 配置"
        sudo $ALTERNATIVES_CMD --remove javac "$JDK_INSTALL_DIR/bin/javac"
        print_success "Javac alternatives 已清理"
    fi
}

jdk_install_download_package() {
    print_section "下载 JDK 安装包"

    # 打印调试信息
    print_debug "当前函数: ${FUNCNAME[0]}"
    print_debug "下载目录: $DOWNLOAD_BASE_DIR"
    print_debug "JDK 版本: $jdk_version"
    print_debug "下载 URL: $download_url"
    print_debug "安装包路径: $jdk_package"
    print_debug "安装目录: $JDK_INSTALL_DIR"

    # 先确保 jdk_package 变量已正确设置
    if [ -z "$jdk_package" ]; then
        jdk_package="$DOWNLOAD_BASE_DIR/$(basename "$download_url")"
    fi
    print_step "下载文件将保存为: $jdk_package"

    # 检查下载目录
    if [ ! -d "$DOWNLOAD_BASE_DIR" ]; then
        print_step "创建下载目录: $DOWNLOAD_BASE_DIR"
        if ! mkdir -p "$DOWNLOAD_BASE_DIR"; then
            print_error "创建下载目录失败"
            exit 1
        fi
    fi

    # 检查网络连接
    local download_host
    download_host=$(echo "$download_url" | cut -d'/' -f3)
    print_step "检查网络连接: $download_host"

    if ! ping -c 1 -W 3 "$download_host" >/dev/null 2>&1; then
        print_error "无法连接到下载服务器: $download_host"
        print_info "请检查:"
        echo "    1. 网络连接是否正常"
        echo "    2. DNS 解析是否正常"
        echo "    3. 是否可以访问 $download_host"
        exit 1
    fi

    print_step "开始下载 JDK"
    print_info "版本: $jdk_version"
    print_info "下载地址: $download_url"

    # 尝试下载，显示进度条
    for i in {1..3}; do
        print_step "第 $i 次尝试下载..."

        # 使用 wget 下载，显示进度，保留错误输出
        if wget --no-check-certificate \
                --progress=bar:force \
                -O "$jdk_package" \
                "$download_url" 2>&1; then
            print_success "下载完成: $jdk_package"
            break
        else
            print_warning "下载失败，错误代码: $?"
            if [ $i -lt 3 ]; then
                print_info "等待 2 秒后重试..."
                sleep 2
            fi
        fi

        if [ $i -eq 3 ]; then
            print_error "下载失败，请检查以下内容："
            print_info "1. 网络连接是否正常"
            print_info "2. 下载地址是否可访问: $download_url"
            print_info "3. 是否有足够的磁盘空间: $(df -h $DOWNLOAD_BASE_DIR)"
            exit 1
        fi
    done

    # 验证下载文件
    if [ ! -f "$jdk_package" ]; then
        print_error "下载文件不存在: $jdk_package"
        exit 1
    fi

    # 检查文件大小
    local file_size
    file_size=$(stat -c%s "$jdk_package" 2>/dev/null || echo 0)
    if [ "$file_size" -lt 1000000 ]; then  # 小于 1MB 可能是错误页面
        print_error "下载的文件大小异常，可能不是有效的 JDK 安装包"
        rm -f "$jdk_package"
        exit 1
    fi
}

jdk_install_prepare_directory() {
    print_section "准备安装目录"

    required_space=500000
    available_space=$(df "$DOWNLOAD_BASE_DIR" | tail -1 | awk '{print $4}')
    if [ "$available_space" -lt "$required_space" ]; then
        print_error "磁盘空间不足，需要至少 500MB 可用空间"
        exit 1
    fi

    if ! mkdir -p "$JDK_INSTALL_DIR"; then
        print_error "创建安装目录失败，请检查权限"
        exit 1
    fi
    print_success "安装目录准备完成: $JDK_INSTALL_DIR"
}

jdk_install_extract_package() {
    print_section "解压 JDK 安装包"
    print_step "正在解压: $jdk_package"

    case "$jdk_package" in
        *.tar.gz|*.tgz)
            if ! tar -xzf "$jdk_package" -C "$JDK_INSTALL_DIR" --strip-components=1; then
                print_error "解压失败"
                exit 1
            fi
            ;;
        *.tar)
            if ! tar -xf "$jdk_package" -C "$JDK_INSTALL_DIR" --strip-components=1; then
                print_error "解压失败"
                exit 1
            fi
            ;;
        *.zip)
            if ! unzip -q "$jdk_package" -d "$JDK_INSTALL_DIR"; then
                print_error "解压失败"
                exit 1
            fi
            ;;
        *)
            print_error "不支持的压缩包格式"
            exit 1
            ;;
    esac

    if [ ! -d "$JDK_INSTALL_DIR/bin" ]; then
        print_error "解压后未找到预期的目录结构"
        exit 1
    fi

    print_success "解压完成: $JDK_INSTALL_DIR"
}

jdk_install_configure_env() {
    print_section "配置环境变量"

    env_file="/etc/profile.d/java_${jdk_version}.sh"
    print_step "创建环境变量配置文件"

    cat <<EOF | sudo tee "$env_file" >/dev/null
# Java 环境变量 - $jdk_version
export JAVA_HOME=$JDK_INSTALL_DIR

# 确保 PATH 中不会重复添加 JAVA_HOME/bin
if [[ ":\$PATH:" != *":\$JAVA_HOME/bin:"* ]]; then
    export PATH=\$PATH:\$JAVA_HOME/bin
fi
EOF

    if [ $? -ne 0 ]; then
        print_error "环境变量配置失败"
        exit 1
    fi

    source "$env_file"
    print_success "环境变量配置完成: $env_file"
}

jdk_install_set_default() {
    print_section "配置默认 Java 版本"

    # 检查 alternatives 命令
    if command -v update-alternatives >/dev/null 2>&1; then
        ALTERNATIVES_CMD="update-alternatives"
    elif command -v alternatives >/dev/null 2>&1; then
        ALTERNATIVES_CMD="alternatives"
    else
        print_warning "未找到 alternatives 命令，跳过配置"
        return
    fi

    # 检查 Java 可执行文件
    if [ ! -x "$JDK_INSTALL_DIR/bin/java" ]; then
        print_error "Java 可执行文件不存在: $JDK_INSTALL_DIR/bin/java"
        exit 1
    fi

    print_step "配置 Java alternatives"

    # 清理已有的 alternatives 配置
    for cmd in java javac jar jps; do
        if $ALTERNATIVES_CMD --display $cmd >/dev/null 2>&1; then
            $ALTERNATIVES_CMD --display $cmd | grep "alternative" | grep -v "status" | while read -r line; do
                path=$(echo "$line" | awk '{print $1}')
                if [ -n "$path" ] && [ -f "$path" ]; then
                    sudo $ALTERNATIVES_CMD --remove $cmd "$path" 2>/dev/null
                fi
            done
        fi
    done

    # 添加新的配置
    print_step "添加新的 alternatives 配置..."
    sudo $ALTERNATIVES_CMD --install /usr/bin/java java "$JDK_INSTALL_DIR/bin/java" 2000 \
        --slave /usr/bin/javac javac "$JDK_INSTALL_DIR/bin/javac" \
        --slave /usr/bin/jar jar "$JDK_INSTALL_DIR/bin/jar" \
        --slave /usr/bin/jps jps "$JDK_INSTALL_DIR/bin/jps"

    # 设置为默认版本
    print_step "设置为默认版本..."
    sudo $ALTERNATIVES_CMD --set java "$JDK_INSTALL_DIR/bin/java"

    # 验证设置
    current_java=$($ALTERNATIVES_CMD --display java | grep "link currently points to" | awk '{print $NF}')

    if [ "$current_java" = "$JDK_INSTALL_DIR/bin/java" ]; then
        print_success "已成功设置 $jdk_version 为默认版本"
    else
        print_warning "alternatives 配置可能未完全生效"
        print_step "创建直接链接..."
        sudo ln -sf "$JDK_INSTALL_DIR/bin/java" /usr/bin/java
        sudo ln -sf "$JDK_INSTALL_DIR/bin/javac" /usr/bin/javac
    fi
}

jdk_install_verify() {
    print_section "验证安装结果"

    source "/etc/profile.d/java_${jdk_version}.sh"

    if [ -x "$JAVA_HOME/bin/java" ]; then
        print_success "Java 安装成功"
        print_info "版本信息如下:"
        "$JAVA_HOME/bin/java" -version 2>&1 | while read -r line; do
            print_info "$line"
        done
    else
        print_error "Java 安装失败"
        print_warning "请运行: source /etc/profile.d/java_${jdk_version}.sh"
        exit 1
    fi
}

jdk_install_finish() {
    end_time=$(date +%s)
    execution_time=$((end_time - start_time))

    print_section "安装完成"
    print_success "Java 安装成功"
    print_info "安装用时: ${execution_time} 秒"
    print_info "Java 版本: $($JAVA_HOME/bin/java -version 2>&1 | head -n 1)"
    print_info "安装路径: $JDK_INSTALL_DIR"
    print_warning "请执行以下命令使环境变量生效:"
    print_info "source /etc/profile.d/java_${jdk_version}.sh"
}

jdk_install() {
    print_debug "开始 JDK 安装流程"
    print_debug "脚本路径: $0"
    print_debug "当前用户: $(whoami)"
    print_debug "系统信息: $(uname -a)"
    print_debug "可用内存: $(free -h)"
    print_debug "可用磁盘: $(df -h /)"

    start_time=$(date +%s)
    jdk_common_cleanup_path
    jdk_common_check_dependencies
    jdk_install_check_existing
    jdk_install_select_version
    jdk_install_cleanup_previous
    jdk_install_download_package
    jdk_install_prepare_directory
    jdk_install_extract_package
    jdk_install_configure_env
    jdk_install_set_default
    jdk_install_verify
    jdk_install_finish
}

# JDK 卸载相关函数
jdk_uninstall_remove_alternatives() {
    print_section "清理 Alternatives 配置"
    print_step "清理 alternatives 配置..."

    if command -v update-alternatives >/dev/null 2>&1; then
        ALTERNATIVES_CMD="update-alternatives"
    elif command -v alternatives >/dev/null 2>&1; then
        ALTERNATIVES_CMD="alternatives"
    else
        print_warning "未找到 alternatives 命令，跳过清理"
        return
    fi

    if [ -n "$ALTERNATIVES_CMD" ]; then
        for cmd in java javac jar jps; do
            if $ALTERNATIVES_CMD --display $cmd >/dev/null 2>&1; then
                $ALTERNATIVES_CMD --display $cmd | grep "alternative" | grep -v "status" | while read -r line; do
                    path=$(echo "$line" | awk '{print $1}')
                    if [ -n "$path" ] && [ -f "$path" ]; then
                        sudo $ALTERNATIVES_CMD --remove $cmd "$path" 2>/dev/null
                    fi
                done
                print_success "$cmd alternatives 已清理"
            fi
        done
    fi
}

jdk_uninstall_remove_env_files() {
    print_section "清理环境变量配置"
    print_step "清理环境变量文件..."

    for env_file in /etc/profile.d/java_*.sh; do
        if [ -f "$env_file" ]; then
            sudo rm -f "$env_file"
            print_success "已删除环境变量文件: $env_file"
        fi
    done
}

jdk_uninstall_remove_installation() {
    print_section "清理安装目录"
    print_step "清理 JDK 安装目录..."

    local java_dirs=("/usr/local/jdk*" "/usr/local/java*" "/usr/local/openjdk*")
    for dir_pattern in "${java_dirs[@]}"; do
        for dir in $dir_pattern; do
            if [ -d "$dir" ]; then
                sudo rm -rf "$dir"
                print_success "已删除目录: $dir"
            fi
        done
    done
}

jdk_uninstall_remove_downloads() {
    print_section "清理下载文件"
    print_step "清理 JDK 安装包..."

    for file in /opt/jdk*.tar.gz /opt/openjdk*.tar.gz; do
        if [ -f "$file" ]; then
            sudo rm -f "$file"
            print_success "已删除文件: $file"
        fi
    done
}

jdk_uninstall_cleanup_env_vars() {
    print_section "清理环境变量"
    print_step "清理当前会话的环境变量..."

    unset JAVA_HOME
    jdk_common_cleanup_path
    print_success "当前会话的环境变量已清理"
}

jdk_uninstall_remove_system_jdk() {
    print_section "清理系统 JDK"
    if command -v java >/dev/null 2>&1 && java -version 2>&1 | grep -i "openjdk" >/dev/null; then
        print_step "清理系统 OpenJDK..."
        if command -v yum >/dev/null 2>&1; then
            sudo yum remove -y java-* java-*-openjdk-* java-*-openjdk-headless
        elif command -v apt-get >/dev/null 2>&1; then
            sudo apt-get remove -y openjdk* java*
            sudo apt-get autoremove -y
        fi
        print_success "系统 OpenJDK 已清理"
    fi
}

jdk_uninstall_remove_symlinks() {
    print_section "清理符号链接"
    print_step "清理 Java 相关符号链接..."

    local links=("/usr/bin/java" "/usr/bin/javac" "/usr/bin/jar" "/usr/bin/jps")
    for link in "${links[@]}"; do
        if [ -L "$link" ]; then
            sudo rm -f "$link"
            print_success "已删除链接: $link"
        fi
    done
}

jdk_uninstall_finish() {
    print_section "卸载完成"
    print_success "JDK 卸载完成"
    echo ""
    print_warning "请执行以下命令使环境变量生效:"
    echo "    source /etc/profile"
    echo ""
    print_info "如需重新安装 JDK，请重新运行此脚本"
}

# 主卸载函数
jdk_uninstall() {
    print_section "卸载 JDK"

    print_warning "此操作将完全删除 JDK 及其配置"
    read -p "[$(date '+%Y-%m-%d %H:%M:%S')] [INPUT] - 确定要继续吗？(y/n): " confirm

    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        print_info "取消卸载"
        return 0
    fi

    print_info "开始清理 Java 进程..."
    jdk_common_check_processes

    print_info "开始清理 alternatives 配置..."
    jdk_uninstall_remove_alternatives

    print_info "开始清理环境变量..."
    jdk_uninstall_remove_env_files

    print_info "卸载完成"
}




# 4. Maven 相关函数
# ======================

# Maven 通用函数
mvn_common_cleanup_path() {
    # 保存原始 IFS
    local OIFS="$IFS"
    IFS=':'

    # 将 PATH 转换为数组
    local -a paths=($PATH)
    declare -A unique_paths
    local new_path=""

    for p in "${paths[@]}"; do
        if [[ "$p" != *"maven"* ]]; then
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

mvn_common_check_dependencies() {
    print_section "检查 Maven 安装依赖"

    # 检查 JDK 是否已安装
    if ! command -v java >/dev/null 2>&1; then
        print_error "未检测到 JDK，Maven 依赖 JDK 环境"
        print_info "请先安装 JDK"
        exit 1
    fi

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

mvn_common_check_processes() {
    print_section "检查运行中的 Maven 进程"
    print_step "检查 Maven 进程..."
    local mvn_processes=$(ps -ef | grep mvn | grep -v grep | grep -v $$ | awk '{print $2}')
    if [ -n "$mvn_processes" ]; then
        print_warning "检测到正在运行的 Maven 进程"
        for pid in $mvn_processes; do
            if kill -0 $pid 2>/dev/null; then
                print_step "正在终止进程 PID: $pid"
                kill -15 $pid 2>/dev/null || kill -9 $pid 2>/dev/null
                sleep 1
            fi
        done
        print_success "Maven 进程已终止"
    else
        print_info "没有检测到运行中的 Maven 进程"
    fi
}

# Maven 安装相关函数
mvn_install_check_existing() {
    print_section "检查现有 Maven 安装"
    if command -v mvn >/dev/null 2>&1; then
        print_info "检测到已安装的 Maven 版本："
        mvn -version
        print_warning "检测到已安装其他版本的 Maven"
        read -p "[$(date '+%Y-%m-%d %H:%M:%S')] [INPUT] - 是否继续安装新版本？(y/n): " continue_choice
        if [ "$continue_choice" != "y" ] && [ "$continue_choice" != "Y" ]; then
            print_info "用户选择不继续安装"
            exit 0
        fi
    else
        print_info "未检测到已安装的 Maven"
    fi
}

mvn_install_select_version() {
    print_section "选择 Maven 版本"
    # 由于只有一个版本，可以简化为：
    mvn_version="apache-maven-3.8.7"
    download_url="https://harborkod.oss-rg-china-mainland.aliyuncs.com/arch/maven/apache-maven-3.8.7-bin.tar.gz"
    MVN_INSTALL_DIR="/usr/local/$mvn_version"

    print_info "将安装: Apache Maven 3.8.7"
    print_debug "安装目录: $MVN_INSTALL_DIR"
    print_debug "下载地址: $download_url"
}

mvn_install_cleanup_previous() {
    print_section "清理历史数据"
    DOWNLOAD_BASE_DIR="/opt"
    mvn_package="$DOWNLOAD_BASE_DIR/$(basename $download_url)"

    if [ -f "$mvn_package" ]; then
        print_step "清理已有安装包: $mvn_package"
        rm -f "$mvn_package"
        print_success "安装包清理完成"
    fi

    if [ -d "$MVN_INSTALL_DIR" ]; then
        print_step "清理已有安装目录: $MVN_INSTALL_DIR"
        rm -rf "$MVN_INSTALL_DIR"
        print_success "安装目录清理完成"
    fi

    env_file="/etc/profile.d/maven_${mvn_version}.sh"
    if [ -f "$env_file" ]; then
        print_step "备份环境变量配置文件: $env_file"
        sudo mv "$env_file" "${env_file}.bak_$(date +%Y%m%d%H%M%S)"
        print_success "配置文件备份完成"
    fi
}

mvn_install_download_package() {
    print_section "下载 Maven 安装包"

    # 打印调试信息
    print_debug "当前函数: ${FUNCNAME[0]}"
    print_debug "下载目录: $DOWNLOAD_BASE_DIR"
    print_debug "Maven 版本: $mvn_version"
    print_debug "下载 URL: $download_url"
    print_debug "安装包路径: $mvn_package"
    print_debug "安装目录: $MVN_INSTALL_DIR"

    # 先确保 mvn_package 变量已正确设置
    if [ -z "$mvn_package" ]; then
        mvn_package="$DOWNLOAD_BASE_DIR/$(basename "$download_url")"
    fi
    print_step "下载文件将保存为: $mvn_package"

    # 检查下载目录
    if [ ! -d "$DOWNLOAD_BASE_DIR" ]; then
        print_step "创建下载目录: $DOWNLOAD_BASE_DIR"
        if ! mkdir -p "$DOWNLOAD_BASE_DIR"; then
            print_error "创建下载目录失败"
            exit 1
        fi
    fi

    # 检查网络连接
    local download_host
    download_host=$(echo "$download_url" | cut -d'/' -f3)
    print_step "检查网络连接: $download_host"

    if ! ping -c 1 -W 3 "$download_host" >/dev/null 2>&1; then
        print_error "无法连接到下载服务器: $download_host"
        print_info "请检查:"
        echo "    1. 网络连接是否正常"
        echo "    2. DNS 解析是否正常"
        echo "    3. 是否可以访问 $download_host"
        exit 1
    fi

    print_step "开始下载 Maven"
    print_info "版本: $mvn_version"
    print_info "下载地址: $download_url"

    # 尝试下载，显示进度条
    for i in {1..3}; do
        print_step "第 $i 次尝试下载..."

        # 使用 wget 下载，显示进度，保留错误输出
        if wget --no-check-certificate \
                --progress=bar:force \
                -O "$mvn_package" \
                "$download_url" 2>&1; then
            print_success "下载完成: $mvn_package"
            break
        else
            print_warning "下载失败，错误代码: $?"
            if [ $i -lt 3 ]; then
                print_info "等待 2 秒后重试..."
                sleep 2
            fi
        fi

        if [ $i -eq 3 ]; then
            print_error "下载失败，请检查以下内容："
            print_info "1. 网络连接是否正常"
            print_info "2. 下载地址是否可访问: $download_url"
            print_info "3. 是否有足够的磁盘空间: $(df -h $DOWNLOAD_BASE_DIR)"
            exit 1
        fi
    done

    # 验证下载文件
    if [ ! -f "$mvn_package" ]; then
        print_error "下载文件不存在: $mvn_package"
        exit 1
    fi

    # 检查文件大小
    local file_size
    file_size=$(stat -c%s "$mvn_package" 2>/dev/null || echo 0)
    if [ "$file_size" -lt 1000000 ]; then  # 小于 1MB 可能是错误页面
        print_error "下载的文件大小异常，可能不是有效的 Maven 安装包"
        rm -f "$mvn_package"
        exit 1
    fi

    print_step "验证文件完整性..."
    local EXPECTED_CHECKSUM="21c2be0a180a326353e8f6d12289f74bc7cd53080305f05358936f3a1b6dd4d91203f4cc799e81761cf5c53c5bbe9dcc13bdb27ec8f57ecf21b2f9ceec3c8d27"
    local ACTUAL_CHECKSUM=$(sha512sum "$mvn_package" | awk '{ print $1 }')
    if [ "$EXPECTED_CHECKSUM" != "$ACTUAL_CHECKSUM" ]; then
        print_error "文件校验失败，下载的文件可能已损坏"
        exit 1
    fi
    print_success "文件校验通过"
}

mvn_install_prepare_directory() {
    print_section "准备安装目录"

    required_space=50000  # Maven 需要的空间比 JDK 小
    available_space=$(df "$DOWNLOAD_BASE_DIR" | tail -1 | awk '{print $4}')
    if [ "$available_space" -lt "$required_space" ]; then
        print_error "磁盘空间不足，需要至少 50MB 可用空间"
        exit 1
    fi

    if ! mkdir -p "$MVN_INSTALL_DIR"; then
        print_error "创建安装目录失败，请检查权限"
        exit 1
    fi
    print_success "安装目录准备完成: $MVN_INSTALL_DIR"
}

mvn_install_extract_package() {
    print_section "解压 Maven 安装包"
    print_step "正在解压: $mvn_package"

    if ! tar -xzf "$mvn_package" -C "$MVN_INSTALL_DIR" --strip-components=1; then
        print_error "解压失败"
        exit 1
    fi

    if [ ! -d "$MVN_INSTALL_DIR/bin" ]; then
        print_error "解压后未找到预期的目录结构"
        exit 1
    fi

    print_success "解压完成: $MVN_INSTALL_DIR"
}

mvn_install_modify_settings() {
    print_section "配置 Maven"

    # 检查本地仓库所需空间
    print_step "检查本地仓库所需空间..."
    local available_space_root=$(df / | tail -1 | awk '{print $4}')
    if [ "$available_space_root" -lt 10000000 ]; then
        print_error "磁盘空间不足，至少需要 10GB 可用空间"
        exit 1
    fi
    print_success "磁盘空间充足"

    # 设置本地仓库
    local local_repo="/repo"
    print_step "配置本地仓库..."
    if [ ! -d "$local_repo" ]; then
        mkdir -p "$local_repo"
        print_success "创建本地仓库目录: $local_repo"
    fi

    # 备份原始配置文件
    local settings_file="$MVN_INSTALL_DIR/conf/settings.xml"
    print_step "备份原始配置..."
    cp "$settings_file" "$settings_file.bak"
    print_success "已备份配置文件到: $settings_file.bak"

    # 更新配置文件
    print_step "更新 Maven 配置..."
    cat <<EOL > "$settings_file"
<?xml version="1.0" encoding="UTF-8"?>
<settings xmlns="http://maven.apache.org/SETTINGS/1.2.0"
          xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
          xsi:schemaLocation="http://maven.apache.org/SETTINGS/1.2.0 https://maven.apache.org/xsd/settings-1.2.0.xsd">

  <localRepository>/repo</localRepository>

  <mirrors>
      <mirror>
          <id>aliyunmaven</id>
          <mirrorOf>*</mirrorOf>
          <name>阿里云公共仓库</name>
          <url>https://maven.aliyun.com/repository/public</url>
      </mirror>
      <mirror>
          <id>nexus-163</id>
          <mirrorOf>*</mirrorOf>
          <name>Nexus 163</name>
          <url>http://mirrors.163.com/maven/repository/maven-public/</url>
      </mirror>
      <mirror>
          <id>huaweicloud</id>
          <mirrorOf>*</mirrorOf>
          <url>https://repo.huaweicloud.com/repository/maven/</url>
      </mirror>
      <mirror>
          <id>nexus-tencentyun</id>
          <mirrorOf>*</mirrorOf>
          <name>Nexus tencentyun</name>
          <url>http://mirrors.cloud.tencent.com/nexus/repository/maven-public/</url>
      </mirror>
  </mirrors>

</settings>
EOL
    print_success "Maven 配置文件已更新"
}

mvn_install_create_user() {
    print_section "配置用户和权限"

    local maven_user="maven"
    local maven_group="maven"

    # 创建用户组
    print_step "创建用户组..."
    if ! getent group "$maven_group" > /dev/null; then
        groupadd "$maven_group"
        print_success "已创建用户组: $maven_group"
    else
        print_info "用户组已存在: $maven_group"
    fi

    # 创建用户
    print_step "创建用户..."
    if ! id "$maven_user" > /dev/null 2>&1; then
        useradd -r -g "$maven_group" -s /usr/sbin/nologin "$maven_user"
        print_success "已创建用户: $maven_user"
    else
        print_info "用户已存在: $maven_user"
    fi

    # 更新权限
    print_step "更新目录权限..."
    if [ -d "$MVN_INSTALL_DIR" ]; then
        chown -R "$maven_user:$maven_group" "$MVN_INSTALL_DIR"
        print_success "已更新安装目录权限: $MVN_INSTALL_DIR"
    else
        print_warning "安装目录不存在: $MVN_INSTALL_DIR"
    fi

    if [ -d "/repo" ]; then
        chown -R "$maven_user:$maven_group" "/repo"
        print_success "已更新仓库目录权限: /repo"
    else
        print_warning "本地仓库目录不存在: /repo"
    fi
}

mvn_install_configure_env() {
    print_section "配置环境变量"

    # 6.1 设置 Maven 环境变量
    env_file="/etc/profile.d/maven.sh"
    print_step "创建环境变量配置..."

    # 先清理已存在的 Maven 路径
    mvn_common_cleanup_path

    # 检查环境变量文件是否存在
    if [ -f "$env_file" ]; then
        print_step "检查现有环境变量配置..."
        if grep -q "MAVEN_HOME=$MVN_INSTALL_DIR" "$env_file" && \
           grep -q "M2_HOME=$MVN_INSTALL_DIR" "$env_file"; then
            print_info "Maven 环境变量已正确配置，无需更改"
            return 0
        else
            print_warning "发现旧的环境变量配置，进行更新..."
            rm -f "$env_file"
        fi
    fi

    # 创建新的环境变量配置
    cat <<EOF > "$env_file"
# Maven 环境变量配置
export MAVEN_HOME=$MVN_INSTALL_DIR
export M2_HOME=$MVN_INSTALL_DIR

# 确保 PATH 中不会重复添加 Maven 路径
if [[ ":\$PATH:" != *":\$MAVEN_HOME/bin:"* ]]; then
    export PATH=\$PATH:\$MAVEN_HOME/bin
fi
EOF

    if [ $? -eq 0 ]; then
        print_success "Maven 环境变量已设置"
        # 刷新当前会话的环境变量
        source "$env_file"
        print_success "环境变量已刷新"
    else
        print_error "环境变量配置失败"
        exit 1
    fi
}

mvn_install_verify() {
    print_section "验证安装结果"

    # 先加载环境变量
    source "/etc/profile.d/maven.sh"

    print_step "检查 Maven 版本..."
    if ! mvn -v; then
        print_error "Maven 安装失败"
        print_warning "请检查环境变量是否生效: source /etc/profile.d/maven.sh"
        exit 1
    fi

    print_success "Maven 安装成功"
}

mvn_install_finish() {
    end_time=$(date +%s)
    execution_time=$((end_time - start_time))

    print_section "安装完成"
    print_success "Maven 安装成功"
    print_info "安装用时: ${execution_time} 秒"
    print_info "Maven 版本: $($MAVEN_HOME/bin/mvn -version | head -n 1)"
    print_info "安装路径: $MVN_INSTALL_DIR"
    print_warning "请执行以下命令使环境变量生效:"
    print_info "source /etc/profile.d/maven.sh"
}

mvn_install() {
    print_debug "开始 Maven 安装流程"
    print_debug "脚本路径: $0"
    print_debug "当前用户: $(whoami)"
    print_debug "系统信息: $(uname -a)"
    print_debug "可用内存: $(free -h)"
    print_debug "可用磁盘: $(df -h /)"

    start_time=$(date +%s)

    mvn_common_cleanup_path
    mvn_common_check_dependencies
    mvn_install_check_existing
    mvn_install_select_version
    mvn_install_cleanup_previous
    mvn_install_download_package
    mvn_install_prepare_directory
    mvn_install_extract_package
    mvn_install_modify_settings
    mvn_install_configure_env
    mvn_install_create_user
    mvn_install_verify
    mvn_install_finish
}

# Maven 卸载相关函数
mvn_uninstall_remove_env_files() {
    print_section "清理环境变量配置"
    print_step "清理环境变量文件..."

    for env_file in /etc/profile.d/maven_*.sh; do
        if [ -f "$env_file" ]; then
            sudo rm -f "$env_file"
            print_success "已删除环境变量文件: $env_file"
        fi
    done
}

mvn_uninstall_remove_installation() {
    print_section "清理安装目录"
    print_step "清理 Maven 安装目录..."

    local maven_dirs=("/usr/local/apache-maven*")
    for dir_pattern in "${maven_dirs[@]}"; do
        for dir in $dir_pattern; do
            if [ -d "$dir" ]; then
                sudo rm -rf "$dir"
                print_success "已删除目录: $dir"
            fi
        done
    done
}

mvn_uninstall_remove_downloads() {
    print_section "清理下载文件"
    print_step "清理 Maven 安装包..."

    for file in /opt/apache-maven*.tar.gz; do
        if [ -f "$file" ]; then
            sudo rm -f "$file"
            print_success "已删除文件: $file"
        fi
    done
}

mvn_uninstall_cleanup_env_vars() {
    print_section "清理环境变量"
    print_step "清理当前会话的环境变量..."

    unset MAVEN_HOME
    mvn_common_cleanup_path
    print_success "当前会话的环境变量已清理"
}

mvn_uninstall_finish() {
    print_section "卸载完成"
    print_success "Maven 卸载完成"
    print_warning "请执行以下命令使环境变量生效:"
    print_info "source /etc/profile"
}

# 主卸载函数
mvn_uninstall() {
    print_section "卸载 Maven"

    print_warning "此操作将完全删除 Maven 及其配置"
    read -p "[$(date '+%Y-%m-%d %H:%M:%S')] [INPUT] - 确定要继续吗？(y/n): " confirm

    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        print_info "取消卸载"
        return 0
    fi

    print_info "开始清理 Maven 进程..."
    mvn_common_check_processes

    # 清理本地仓库
    if [ -d "$MVN_LOCAL_REPO" ]; then
        print_warning "检测到 Maven 本地仓库: $MVN_LOCAL_REPO"
        read -p "[$(date '+%Y-%m-%d %H:%M:%S')] [INPUT] - 是否删除本地仓库？(y/n): " remove_repo
        if [ "$remove_repo" = "y" ] || [ "$remove_repo" = "Y" ]; then
            rm -rf "$MVN_LOCAL_REPO"
            print_success "已删除本地仓库"
        else
            print_info "保留本地仓库"
        fi
    fi

    print_info "开始清理环境变量..."
    mvn_uninstall_remove_env_files
    mvn_uninstall_remove_installation
    mvn_uninstall_remove_downloads
    mvn_uninstall_cleanup_env_vars
    mvn_uninstall_finish
}




# 5. Redis 相关函数
# ======================

# Redis 通用函数
redis_common_check_dependencies() {
    print_section "检查 Redis 安装依赖"

    # 检查 root 权限
    if [ "$EUID" -ne 0 ] && ! command -v sudo >/dev/null 2>&1; then
        print_error "此脚本需要 root 权限或 sudo 命令"
        exit 1
    fi

    # 检查必要的命令
    for cmd in wget tar gcc make; do
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

redis_common_check_processes() {
    print_section "检查 Redis 进程"
    print_step "检查是否有正在运行的 Redis 进程..."

    # 检查端口 6379 是否被占用
    local pid=$(lsof -t -i:6379)
    if [ -n "$pid" ]; then
        print_warning "检测到占用 6379 端口的进程 (PID: $pid)"
        kill -9 $pid
        print_success "已终止占用 6379 端口的进程"
    fi

    # 检查 redis-server 进程
    if pgrep -x "redis-server" > /dev/null; then
        print_warning "检测到正在运行的 Redis 进程"
        pkill redis-server
        print_success "Redis 进程已终止"
    else
        print_info "未检测到运行中的 Redis 进程"
    fi
}

# Redis 安装相关函数
redis_install_cleanup_previous() {
    print_section "清理历史数据"

    # 检查并终止 Redis 进程
    redis_common_check_processes

    # 删除旧的安装目录
    if [ -d "$REDIS_INSTALL_DIR" ]; then
        print_step "删除旧的 Redis 安装目录..."
        rm -rf "$REDIS_INSTALL_DIR"
        print_success "已删除安装目录"
    fi

    # 删除旧的源代码目录
    if [ -d "$REDIS_SRC_DIR" ]; then
        print_step "删除旧的 Redis 源代码目录..."
        rm -rf "$REDIS_SRC_DIR"
        print_success "已删除源代码目录"
    fi

    # 删除旧的配置文件
    if [ -f "/etc/redis.conf" ]; then
        print_step "备份旧的配置文件..."
        mv /etc/redis.conf "/etc/redis.conf.bak_$(date +%F_%T)"
        print_success "已备份配置文件"
    fi
}

redis_install_download_package() {
    print_section "下载 Redis 源码"
    cd "$DOWNLOAD_BASE_DIR"

    local package_name="redis-${REDIS_VERSION}.tar.gz"
    if [ -f "$package_name" ]; then
        print_info "Redis 源码包已存在，跳过下载"
    else
        print_step "下载 Redis 源码包..."
        if ! wget -O "$package_name" "$REDIS_SOURCE_URL"; then
            print_error "下载 Redis 源码包失败"
            exit 1
        fi
        print_success "下载完成"
    fi

    print_step "解压源码包..."
    tar -zxf "$package_name" -C /usr/local/
    mv "/usr/local/redis-${REDIS_VERSION}" "$REDIS_SRC_DIR"
    print_success "解压完成"
}

redis_install_compile() {
    print_section "编译 Redis"
    cd "$REDIS_SRC_DIR"

    print_step "开始编译..."
    if ! make -j$(nproc); then
        print_error "编译失败"
        exit 1
    fi

    print_step "安装到指定目录..."
    if ! make install PREFIX="$REDIS_INSTALL_DIR"; then
        print_error "安装失败"
        exit 1
    fi

    print_success "编译安装完成"
}

redis_install_configure() {
    print_section "配置 Redis"

    # 创建必要的目录
    print_step "创建标准目录结构..."
    mkdir -p "$REDIS_CONF_DIR" "$REDIS_LOG_DIR" "$REDIS_DATA_DIR"

    # 创建配置文件
    print_step "创建配置文件..."
    cat > "${REDIS_CONF_DIR}/redis.conf" <<EOF
# 基本配置
daemonize yes
pidfile /run/redis.pid
port 6379
bind 0.0.0.0
timeout 0

# 日志配置
loglevel notice
logfile ${REDIS_LOG_DIR}/redis.log

# 数据目录配置
dir ${REDIS_DATA_DIR}
dbfilename dump.rdb

# 认证配置
requirepass ${REDIS_PASSWORD}

# 数据库配置
databases 16

# 持久化配置
save 900 1
save 300 10
save 60 10000
rdbcompression yes
rdbchecksum yes

# AOF 配置
appendonly yes
appendfilename "appendonly.aof"
appendfsync everysec

# 其他配置
no-appendfsync-on-rewrite no
auto-aof-rewrite-percentage 100
auto-aof-rewrite-min-size 64mb
EOF

    # 设置配置文件权限
    if ! getent group "$REDIS_GROUP" > /dev/null; then
        groupadd "$REDIS_GROUP"
    fi

    chown root:"$REDIS_GROUP" "${REDIS_CONF_DIR}/redis.conf"
    chmod 640 "${REDIS_CONF_DIR}/redis.conf"

    print_success "配置文件创建完成"
}

redis_install_create_user() {
    print_section "创建用户和权限"

    # 创建用户组和用户
    if ! getent group "$REDIS_GROUP" > /dev/null; then
        print_step "创建用户组..."
        groupadd "$REDIS_GROUP"
        print_success "用户组创建完成"
    fi

    if ! id "$REDIS_USER" > /dev/null 2>&1; then
        print_step "创建用户..."
        useradd -r -g "$REDIS_GROUP" -d "$REDIS_DATA_DIR" -s /usr/sbin/nologin "$REDIS_USER"
        print_success "用户创建完成"
    fi

    # 创建并设置目录权限
    print_step "创建并设置目录权限..."
    mkdir -p "$REDIS_INSTALL_DIR" "$REDIS_DATA_DIR" "$REDIS_LOG_DIR" "$REDIS_CONF_DIR"

    chown -R "$REDIS_USER:$REDIS_GROUP" "$REDIS_INSTALL_DIR"
    chown -R "$REDIS_USER:$REDIS_GROUP" "$REDIS_DATA_DIR"
    chown -R "$REDIS_USER:$REDIS_GROUP" "$REDIS_LOG_DIR"
    chown root:"$REDIS_GROUP" "$REDIS_CONF_DIR"

    chmod 755 "$REDIS_INSTALL_DIR"
    chmod 750 "$REDIS_DATA_DIR"
    chmod 750 "$REDIS_LOG_DIR"
    chmod 750 "$REDIS_CONF_DIR"

    print_success "用户和权限配置完成"
}

redis_install_configure_env() {
    print_section "配置环境变量"

    env_file="/etc/profile.d/redis.sh"
    print_step "创建环境变量配置文件..."

    cat > "$env_file" <<EOF
# Redis 环境变量配置
export REDIS_HOME=${REDIS_INSTALL_DIR}

# 确保 PATH 中不会重复添加 Redis 路径
if [[ ":\$PATH:" != *":\$REDIS_HOME/bin:"* ]]; then
    export PATH=\$PATH:\$REDIS_HOME/bin
fi
EOF

    if [ $? -eq 0 ]; then
        print_success "Redis 环境变量已设置"
        # 刷新当前会话的环境变量
        source "$env_file"
        print_success "环境变量已刷新"
    else
        print_error "环境变量配置失败"
        exit 1
    fi
}

redis_install_setup_service() {
    print_section "配置系统服务"

    print_step "创建 systemd 服务文件..."
    cat > /etc/systemd/system/redis.service <<EOF
[Unit]
Description=Redis In-Memory Data Store
After=network.target

[Service]
Type=forking
PIDFile=/run/redis.pid

# ExecStartPre: 启动前处理
ExecStartPre=/bin/sh -c 'if [ -f /run/redis.pid ]; then rm -f /run/redis.pid; fi'
ExecStartPre=/bin/sh -c 'touch /run/redis.pid'

# ExecStart: 启动服务的主命令
ExecStart=${REDIS_INSTALL_DIR}/bin/redis-server ${REDIS_CONF_DIR}/redis.conf

# ExecStartPost: 在服务启动之后执行的命令，这里用于等待 PID 文件创建
ExecStartPost=/bin/sh -c 'while ! test -f /run/redis.pid; do sleep 0.1; done'

# ExecStop: 停止服务的命令
ExecStop=${REDIS_INSTALL_DIR}/bin/redis-cli -a ${REDIS_PASSWORD} shutdown

# 重启设置
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

    print_step "重载 systemd 配置..."
    systemctl daemon-reload

    print_step "启用 Redis 服务..."
    systemctl enable redis

    print_step "启动 Redis 服务..."
    if ! systemctl start redis; then
        print_error "Redis 服务启动失败"

        print_info "===== 服务状态 ====="
        systemctl status redis 2>&1

        print_info "===== 系统日志 ====="
        journalctl -xe --unit=redis 2>&1

        print_info "===== Redis 日志 ====="
        tail -n 50 "${REDIS_LOG_DIR}/redis.log" 2>&1

        exit 1
    fi

    # 等待服务完全启动
    sleep 2

    print_success "系统服务配置完成"
}

redis_install_verify() {
    print_section "验证安装结果"

    print_step "检查 Redis 服务状态..."
    if ! systemctl is-active redis >/dev/null 2>&1; then
        print_error "Redis 服务未能正常启动"
        exit 1
    fi

    print_step "检查 Redis 连接..."
    # 直接使用 -a 参数，忽略警告信息
    if ! "$REDIS_INSTALL_DIR/bin/redis-cli" -a "$REDIS_PASSWORD" ping 2>/dev/null | grep -q "PONG"; then
        print_error "Redis 连接测试失败"
        exit 1
    fi

    print_success "Redis 安装验证通过"
}

redis_install_finish() {
    print_section "安装完成"
    print_success "Redis 安装成功"
    print_info "Redis 版本: ${REDIS_VERSION}"
    print_info "安装路径: ${REDIS_INSTALL_DIR}"
    print_info "数据目录: ${REDIS_DATA_DIR}"
    print_info "日志目录: ${REDIS_LOG_DIR}"
    print_info "Redis 密码: ${REDIS_PASSWORD}"
    print_info "服务管理命令:"
    print_info "  启动: systemctl start redis"
    print_info "  停止: systemctl stop redis"
    print_info "  重启: systemctl restart redis"
    print_info "  状态: systemctl status redis"
}

# Redis 主安装函数
redis_install() {
    print_debug "开始 Redis 安装流程"
    start_time=$(date +%s)

    # 先执行卸载操作，传入静默参数
    print_step "执行清理操作..."
    redis_uninstall true >/dev/null 2>&1 || true

    # 继续安装流程
    redis_common_check_dependencies
    redis_install_cleanup_previous
    redis_install_prepare_directories
    redis_install_download_package
    redis_install_compile
    redis_install_configure
    redis_install_create_user
    redis_install_configure_env
    redis_install_setup_service
    redis_install_verify
    redis_install_finish
}

# Redis 卸载相关函数
redis_uninstall_stop_service() {
    print_section "停止 Redis 服务"

    print_step "停止 Redis 服务..."
    if systemctl is-active redis >/dev/null 2>&1; then
        systemctl stop redis
        print_success "Redis 服务已停止"
    fi

    print_step "禁用 Redis 服务..."
    if systemctl is-enabled redis >/dev/null 2>&1; then
        systemctl disable redis
        print_success "Redis 服务已禁用"
    fi

    print_step "删除服务文件..."
    if [ -f "/etc/systemd/system/redis.service" ]; then
        rm -f "/etc/systemd/system/redis.service"
        print_success "服务文件已删除"
    fi

    # 新增：完全清理 systemd 状态
    print_step "清理 systemd 状态..."
    systemctl daemon-reload
    systemctl reset-failed redis
    print_success "systemd 状态已清理"
}

redis_uninstall_remove_files() {
    print_section "删除 Redis 文件"

    # 获取静默模式参数
    local is_silent=${1:-false}

    # 删除标准目录结构
    local dirs=(
        "$REDIS_INSTALL_DIR"
        "$REDIS_CONF_DIR"
        "$REDIS_SRC_DIR"
    )

    for dir in "${dirs[@]}"; do
        if [ -d "$dir" ]; then
            print_step "删除目录: $dir..."
            rm -rf "$dir"
            print_success "目录已删除: $dir"
        fi
    done

    # 数据和日志目录需要确认
    if [ -d "$REDIS_DATA_DIR" ] || [ -d "$REDIS_LOG_DIR" ]; then
        if [ "$is_silent" = "true" ]; then
            # 静默模式下直接删除
            rm -rf "$REDIS_DATA_DIR" "$REDIS_LOG_DIR"
        else
            print_warning "检测到数据、日志目录"
            read -p "[$(date '+%Y-%m-%d %H:%M:%S')] [INPUT] - 是否删除这些目录？(y/n): " remove_data
            if [ "$remove_data" = "y" ] || [ "$remove_data" = "Y" ]; then
                rm -rf "$REDIS_DATA_DIR" "$REDIS_LOG_DIR"
                print_success "数据、日志目录已删除"
            else
                print_info "保留数据、日志目录"
            fi
        fi
    fi
}

redis_uninstall_remove_env_files() {
    print_section "清理环境变量配置"
    print_step "清理环境变量文件..."

    if [ -f "/etc/profile.d/redis.sh" ]; then
        rm -f "/etc/profile.d/redis.sh"
        print_success "环境变量文件已删除"
    fi

    # 清理当前会话的环境变量
    unset REDIS_HOME
    # 清理 PATH 中的 Redis 路径
    export PATH=$(echo $PATH | tr ':' '\n' | grep -v "redis" | tr '\n' ':' | sed 's/:$//')

    print_success "环境变量已清理"
}

redis_uninstall_remove_user() {
    print_section "删除 Redis 用户"

    if id "$REDIS_USER" >/dev/null 2>&1; then
        print_step "删除用户..."
        userdel "$REDIS_USER"
        print_success "用户已删除"
    fi

    if getent group "$REDIS_GROUP" >/dev/null; then
        print_step "删除用户组..."
        groupdel "$REDIS_GROUP"
        print_success "用户组已删除"
    fi
}

redis_uninstall_finish() {
    print_section "卸载完成"
    print_success "Redis 已完全卸载"
    print_info "如需重新安装，请重新运行此脚本"
}

# Redis 主卸载函数
redis_uninstall() {
    print_section "卸载 Redis"

    # 如果是通过安装函数调用的，则静默执行
    local is_silent=${1:-false}

    if [ "$is_silent" = "false" ]; then
        print_warning "此操作将完全删除 Redis 及其配置"
        read -p "[$(date '+%Y-%m-%d %H:%M:%S')] [INPUT] - 确定要继续吗？(y/n): " confirm

        if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
            print_info "取消卸载"
            return 0
        fi
    fi

    redis_common_check_processes
    redis_uninstall_stop_service
    redis_uninstall_remove_files "$is_silent"  # 传递静默参数
    redis_uninstall_remove_env_files
    redis_uninstall_remove_user
    redis_uninstall_finish
}

# Redis 管理菜单
manage_redis() {
    print_section "Redis 管理"
    print_info "请选择操作:"
    print_info "1) 安装 Redis"
    print_info "2) 卸载 Redis"
    print_info "3) 返回主菜单"

    read -p "[$(date '+%Y-%m-%d %H:%M:%S')] [INPUT] - 请输入选项 [1-3]: " choice

    case $choice in
        1) redis_install ;;
        2) redis_uninstall ;;
        3) main ;;
        *) print_error "无效的选择"; exit 1 ;;
    esac
}




# 6. MySQL 相关函数
# ======================

# MySQL 通用函数


# MySQL 安装主函数

# ==============================================
# MySQL 通用函数
# ==============================================

# 检查磁盘空间
mysql_common_check_disk() {
    AVAILABLE_SPACE=$(df /usr/local | tail -1 | awk '{print $4}')
    if [ "$AVAILABLE_SPACE" -lt 5000000 ]; then
        print_error "磁盘空间不足，至少需要 5GB 可用空间。"
        exit 1
    fi
}

# 检查内存空间
mysql_common_check_mem() {
    TOTAL_MEM=$(free -m | awk '/^Mem:/{print $2}')
    AVAILABLE_MEM=$(free -m | awk '/^Mem:/{print $7}')

    # 当前内存总大小，当前内存可用大小
    print_info "当前内存总大小: $TOTAL_MEM MB"
    print_info "当前内存可用大小: $AVAILABLE_MEM MB"

    # 总内存空间至少3.5GB
    if [ "$TOTAL_MEM" -lt 3500 ]; then
        print_error "内存空间不足，至少需要 3.5GB 可用内存。"
        exit 1
    fi

    # 可用内存空间至少3GB
    if [ "$AVAILABLE_MEM" -lt 3500 ]; then
        print_error "内存空间不足，至少需要 3.5GB 可用内存。"
        exit 1
    fi
}

# 检查并安装 MySQL 依赖
mysql_common_check_dependencies() {
    print_section "检查 MySQL 安装依赖"

    # 检查 root 权限
    if [ "$EUID" -ne 0 ] && ! command -v sudo >/dev/null 2>&1; then
        print_error "此脚本需要 root 权限或 sudo 命令"
        exit 1
    fi

    # 检测操作系统
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        VERSION=$VERSION_ID
    else
        print_error "无法检测操作系统"
        exit 1
    fi

    print_info "检测到系统: $OS $VERSION"

    # 依赖列表
    dependencies=("gcc" "gcc-c++" "ncurses-devel" "openssl" "openssl-devel" "bison" "bzip2" "make" "cmake" "perl" "wget" "tar" "libtirpc-devel")

    # `rpcgen` 需要特殊处理
    need_rpcgen=false
    if ! command -v rpcgen >/dev/null 2>&1; then
        need_rpcgen=true
    fi

    # 根据系统选择包管理器
    if command -v apt-get >/dev/null 2>&1; then
        PKG_MANAGER="apt-get"
        INSTALL_CMD="apt-get install -y"
    elif command -v dnf >/dev/null 2>&1; then
        PKG_MANAGER="dnf"
        INSTALL_CMD="dnf install -y"
    elif command -v yum >/dev/null 2>&1; then
        PKG_MANAGER="yum"
        INSTALL_CMD="yum install -y"
    elif command -v pacman >/dev/null 2>&1; then
        PKG_MANAGER="pacman"
        INSTALL_CMD="pacman -Sy --noconfirm"
    elif command -v apk >/dev/null 2>&1; then
        PKG_MANAGER="apk"
        INSTALL_CMD="apk add --no-cache"
    elif command -v zypper >/dev/null 2>&1; then
        PKG_MANAGER="zypper"
        INSTALL_CMD="zypper install -y"
    else
        print_error "无法检测合适的包管理器"
        exit 1
    fi

    print_info "使用包管理器: $PKG_MANAGER"

    # 逐个检查并安装依赖
    for pkg in "${dependencies[@]}"; do
        case "$PKG_MANAGER" in
            apt-get)
                if ! dpkg -s "$pkg" &>/dev/null 2>&1; then
                    print_warning "未检测到 $pkg，正在安装..."
                    sudo $INSTALL_CMD "$pkg"
                    print_success "$pkg 安装完成"
                else
                    print_success "$pkg 已安装"
                fi
                ;;
            yum|dnf)
                if ! rpm -q "$pkg" &>/dev/null; then
                    print_warning "未检测到 $pkg，正在安装..."
                    sudo $INSTALL_CMD "$pkg"
                    print_success "$pkg 安装完成"
                else
                    print_success "$pkg 已安装"
                fi
                ;;
            pacman)
                if ! pacman -Qi "$pkg" &>/dev/null; then
                    print_warning "未检测到 $pkg，正在安装..."
                    sudo $INSTALL_CMD "$pkg"
                    print_success "$pkg 安装完成"
                else
                    print_success "$pkg 已安装"
                fi
                ;;
            apk)
                if ! apk info "$pkg" &>/dev/null; then
                    print_warning "未检测到 $pkg，正在安装..."
                    sudo $INSTALL_CMD "$pkg"
                    print_success "$pkg 安装完成"
                else
                    print_success "$pkg 已安装"
                fi
                ;;
            zypper)
                if ! rpm -q "$pkg" &>/dev/null; then
                    print_warning "未检测到 $pkg，正在安装..."
                    sudo $INSTALL_CMD "$pkg"
                    print_success "$pkg 安装完成"
                else
                    print_success "$pkg 已安装"
                fi
                ;;
        esac
    done

    # 处理 `rpcgen` 安装
    if $need_rpcgen; then
        print_warning "未检测到 rpcgen，正在安装..."

        case "$OS" in
            rocky|almalinux|centos)
                print_info "Rocky/Alma/CentOS 需要启用 powertools 进行安装"
                sudo dnf install -y --enablerepo=powertools rpcgen
                ;;
            rhel)
                print_info "RHEL 需要启用 CodeReady Builder 仓库"
                sudo subscription-manager repos --enable "codeready-builder-for-rhel-$(rpm -E %rhel)-$(arch)-rpms"
                sudo dnf install -y rpcgen
                ;;
            debian|ubuntu)
                print_info "Debian/Ubuntu 直接使用 apt-get 安装"
                sudo apt-get install -y rpcgen
                ;;
            arch)
                print_info "Arch Linux 直接使用 pacman 安装"
                sudo pacman -Sy --noconfirm rpcgen
                ;;
            alpine)
                print_info "Alpine Linux 直接使用 apk 安装"
                sudo apk add --no-cache rpcgen
                ;;
            opensuse|sles)
                print_info "openSUSE / SLES 直接使用 zypper 安装"
                sudo zypper install -y rpcgen
                ;;
            *)
                print_error "不支持的系统: $OS，无法自动安装 rpcgen，请手动安装"
                exit 1
                ;;
        esac

        # 检查是否安装成功
        if command -v rpcgen >/dev/null 2>&1; then
            print_success "rpcgen 安装完成"
        else
            print_error "rpcgen 安装失败，请手动检查"
            exit 1
        fi
    else
        print_success "rpcgen 已安装"
    fi
}

# 检查 MySQL 进程
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

# 清理原有的配置及环境
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
        "$MYSQL_BACKUP_DIR"       # 备份目录
        "$MYSQL_TMP_DIR"          # 临时目录
        "$MYSQL_BINLOG_DIR"       # 二进制日志目录
        "$MYSQL_RELAYLOG_DIR"     # 中继日志目录
        "$MYSQL_SRC_DIR"          # 源码目录
        "$MYSQL_PID_DIR"          # pid目录
        "$MYSQL_BOOST_INSTALL_DIR"      # Boost库目录
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

# ==============================================
# MySQL 安装相关函数
# ==============================================
# 选择 MySQL 版本
mysql_install_select_version() {
    print_debug "PRE-MYSQL_VERSION: $MYSQL_VERSION"
    print_debug "PRE-MYSQL_SOURCE_URL: $MYSQL_SOURCE_URL"
    print_debug "PRE-MYSQL_INSTALL_DIR: $MYSQL_INSTALL_DIR"
    print_debug "PRE-MYSQL_CONF_DIR: $MYSQL_CONF_DIR"
    print_debug "PRE-MYSQL_LOG_DIR: $MYSQL_LOG_DIR"
    print_debug "PRE-MYSQL_DATA_DIR: $MYSQL_DATA_DIR"
    print_debug "PRE-MYSQL_BACKUP_DIR: $MYSQL_BACKUP_DIR"
    print_debug "PRE-MYSQL_TMP_DIR: $MYSQL_TMP_DIR"
    print_debug "PRE-MYSQL_BINLOG_DIR: $MYSQL_BINLOG_DIR"
    print_debug "PRE-MYSQL_SRC_DIR: $MYSQL_SRC_DIR"
    print_debug "PRE-MYSQL_BOOST_INSTALL_DIR: $MYSQL_BOOST_INSTALL_DIR"

    print_section "选择 MySQL 版本"
    print_info "请选择要安装的 MySQL 版本："
    print_info "1) MySQL 5.7.37"
    print_info "2) MySQL 8.0.24"
    read -p "[$(date '+%Y-%m-%d %H:%M:%S')] [INPUT] - 请输入选项 [1-2]: " choice

    case $choice in
        1)
            MYSQL_VERSION="5.7.37"
            MYSQL_SOURCE_URL="https://harborkod.oss-rg-china-mainland.aliyuncs.com/arch/mysql/mysql-5.7.37.tar.gz"
            MYSQL_SRC_DIR="/usr/local/src/mysql-5.7.37"
            ;;
        2)
            MYSQL_VERSION="8.0.24"
            MYSQL_SOURCE_URL="https://harborkod.oss-rg-china-mainland.aliyuncs.com/arch/mysql/mysql-8.0.24.tar.gz"
            MYSQL_SRC_DIR="/usr/local/src/mysql-8.0.24"
            ;;
        *)
            print_error "无效的选择"
            exit 1
            ;;
    esac

    print_success "已选择: MySQL ${MYSQL_VERSION}"

    print_debug "AFTER-MYSQL_VERSION: $MYSQL_VERSION"
    print_debug "AFTER-MYSQL_SOURCE_URL: $MYSQL_SOURCE_URL"
    print_debug "AFTER-MYSQL_INSTALL_DIR: $MYSQL_INSTALL_DIR"
    print_debug "AFTER-MYSQL_CONF_DIR: $MYSQL_CONF_DIR"
    print_debug "AFTER-MYSQL_LOG_DIR: $MYSQL_LOG_DIR"
    print_debug "AFTER-MYSQL_DATA_DIR: $MYSQL_DATA_DIR"
    print_debug "AFTER-MYSQL_BACKUP_DIR: $MYSQL_BACKUP_DIR"
    print_debug "AFTER-MYSQL_TMP_DIR: $MYSQL_TMP_DIR"
    print_debug "AFTER-MYSQL_BINLOG_DIR: $MYSQL_BINLOG_DIR"
    print_debug "AFTER-MYSQL_SRC_DIR: $MYSQL_SRC_DIR"
    print_debug "AFTER-MYSQL_BOOST_INSTALL_DIR: $MYSQL_BOOST_INSTALL_DIR"
}

# 创建 MySQL 用户和组
mysql_install_create_user() {
    print_section "创建用户和用户组"

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

    print_success "用户和用户组创建完成"
}

# 创建必要的目录
mysql_install_prepare_directories() {
    print_section "准备目录结构"

    # 创建标准目录结构
    print_step "创建必要的目录..."
    for dir in \
        "$MYSQL_INSTALL_DIR" \
        "$MYSQL_CONF_DIR" \
        "$MYSQL_LOG_DIR" \
        "$MYSQL_DATA_DIR" \
        "$MYSQL_BACKUP_DIR" \
        "$MYSQL_TMP_DIR" \
        "$MYSQL_BINLOG_DIR" \
        "$MYSQL_RELAYLOG_DIR" \
        "$MYSQL_SRC_DIR" \
        "$MYSQL_PID_DIR"; do
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
    chmod 750 "$MYSQL_BACKUP_DIR"
    chmod 750 "$MYSQL_TMP_DIR"
    chmod 750 "$MYSQL_BINLOG_DIR"
    chmod 750 "$MYSQL_RELAYLOG_DIR"
    chmod 750 "$MYSQL_SRC_DIR"
    chmod 755 "$MYSQL_PID_DIR"

    print_success "目录结构准备完成"
}

# 分配 MySQL 用户权限
mysql_install_grant_user() {
    print_section "分配 MySQL 用户权限"

    # 判断用户组是否存在
    if ! getent group "$MYSQL_GROUP" > /dev/null; then
        print_error "用户组不存在: $MYSQL_GROUP"
        exit 1
    fi

    # 判断用户是否存在
    if ! id "$MYSQL_USER" > /dev/null 2>&1; then
        print_error "用户不存在: $MYSQL_USER"
        exit 1
    fi

    # 设置目录权限
    print_step "设置目录权限..."
    chown -R "$MYSQL_USER:$MYSQL_GROUP" "$MYSQL_INSTALL_DIR"
    chown -R "$MYSQL_USER:$MYSQL_GROUP" "$MYSQL_CONF_DIR"
    chown -R "$MYSQL_USER:$MYSQL_GROUP" "$MYSQL_LOG_DIR"
    chown -R "$MYSQL_USER:$MYSQL_GROUP" "$MYSQL_DATA_DIR"
    chown -R "$MYSQL_USER:$MYSQL_GROUP" "$MYSQL_BACKUP_DIR"
    chown -R "$MYSQL_USER:$MYSQL_GROUP" "$MYSQL_TMP_DIR"
    chown -R "$MYSQL_USER:$MYSQL_GROUP" "$MYSQL_BINLOG_DIR"
    chown -R "$MYSQL_USER:$MYSQL_GROUP" "$MYSQL_RELAYLOG_DIR"
    chown -R "$MYSQL_USER:$MYSQL_GROUP" "$MYSQL_SRC_DIR"
    chown -R "$MYSQL_USER:$MYSQL_GROUP" "$MYSQL_PID_DIR"

    # 设置权限
    chmod 755 "$MYSQL_INSTALL_DIR"
    chmod 750 "$MYSQL_CONF_DIR"
    chmod 750 "$MYSQL_LOG_DIR"
    chmod 750 "$MYSQL_DATA_DIR"
    chmod 750 "$MYSQL_BACKUP_DIR"
    chmod 750 "$MYSQL_TMP_DIR"
    chmod 750 "$MYSQL_BINLOG_DIR"
    chmod 750 "$MYSQL_RELAYLOG_DIR"
    chmod 750 "$MYSQL_SRC_DIR"
    chmod 755 "$MYSQL_PID_DIR"

    print_success "用户和权限配置完成"
}

# 下载并安装 Boost 库
mysql_install_download_boost() {
    print_section "下载 Boost 库"
    if [ -d "$MYSQL_BOOST_INSTALL_DIR" ]; then
        print_info "Boost 库已存在，跳过下载"
        return 0
    fi

    print_step "创建 Boost 安装目录..."
    mkdir -p "$MYSQL_BOOST_INSTALL_DIR"
    cd "$DOWNLOAD_BASE_DIR"

    print_step "下载 Boost 库..."
    if ! wget -O "boost_${MYSQL_BOOST_VERSION}.tar.gz" "$MYSQL_BOOST_SOURCE_URL" --no-check-certificate; then
        print_error "下载 Boost 库失败"
        exit 1
    fi

    print_step "解压 Boost 库..."
    if ! tar -zxf "boost_${MYSQL_BOOST_VERSION}.tar.gz" -C "$MYSQL_BOOST_INSTALL_DIR" --strip-components=1; then
        print_error "解压 Boost 库失败"
        exit 1
    fi

    if [ "$(ls -A $MYSQL_BOOST_INSTALL_DIR)" ]; then
        print_success "Boost 库安装完成"
    else
        print_error "Boost 库安装失败，目录为空"
        exit 1
    fi
}

# 下载 MySQL 源码
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

    # 解压源码包到指定目录
    tar -zxf "$package_name" -C /usr/local/

    # 校验解压目录是否存在
    if [ ! -d "/usr/local/mysql-${MYSQL_VERSION}" ]; then
        print_error "解压失败，目录不存在"
        exit 1
    fi

    # 将解压后的文件复制到源码目录
    cp -r /usr/local/mysql-${MYSQL_VERSION}/. "$MYSQL_SRC_DIR"

    # 确认复制成功
    if [ ! -d "$MYSQL_SRC_DIR" ]; then
        print_error "复制失败，目录不存在"
        exit 1
    fi

    # 删除掉源目录
    rm -rf /usr/local/mysql-${MYSQL_VERSION}

    print_success "解压完成"
}

# 编译安装 MySQL
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
        -DWITH_BOOST="$MYSQL_BOOST_INSTALL_DIR"

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

# MySQL 配置文件
mysql_install_configure_cnf() {
    print_section "配置 MySQL"
    print_step "创建配置文件..."

    cat > "$MYSQL_CONF_DIR/my.cnf" <<EOF
[client]
port   = 3306
socket = $MYSQL_DATA_DIR/mysql.sock
default-character-set = utf8mb4


[mysql]
host = localhost
default-character-set = utf8mb4
user = root
password = '$MYSQL_ROOT_PASSWORD'
auto-vertical-output


[mysqld]
# 基本配置
user = mysql
default-time-zone = 'SYSTEM'
log_timestamps=SYSTEM
port = 3306
autocommit     = ON
basedir = $MYSQL_INSTALL_DIR
datadir = $MYSQL_DATA_DIR
tmpdir  = $MYSQL_TMP_DIR
pid-file = /run/mysql/mysql.pid
socket  = $MYSQL_DATA_DIR/mysql.sock
lower_case_table_names = 1

# 允许所有 IP 访问
bind-address = 0.0.0.0

# 存储引擎配置
default-storage-engine = INNODB
innodb_file_per_table = 1

# 字符集配置
character-set-server = utf8mb4
collation-server = utf8mb4_general_ci

# 日志配置
log-error = $MYSQL_LOG_DIR/error.log
long_query_time = 2

# general_log 日志配置
general_log = 1
general_log_file = $MYSQL_LOG_DIR/general.log

# slow_query_log 日志配置
slow_query_log = 1
log_queries_not_using_indexes = 1
slow_query_log_file = $MYSQL_LOG_DIR/slow.log

# binlog 日志配置
server-id = 1
binlog_format = ROW
expire_logs_days = 7
max_binlog_size = 1G
log-bin = $MYSQL_BINLOG_DIR/mysql-bin

# relay_log 日志配置
relay_log = $MYSQL_RELAYLOG_DIR/mysql-relay-bin
relay_log_index = $MYSQL_RELAYLOG_DIR/mysql-relay-bin.index
relay_log_info_file = $MYSQL_RELAYLOG_DIR/relay-log.info

# 其他优化配置
max_connections = 1000
open_files_limit = 65535
table_open_cache = 2048
max_allowed_packet = 16M


[mysqldump]
quick
single-transaction

EOF

    if [ $? -ne 0 ]; then
        print_error "配置文件创建失败"
        exit 1
    fi
    print_success "配置文件创建完成"
}

# 设置环境变量
mysql_install_configure_path() {
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

    # 立即生效环境变量
    source $ENV_FILE

    # 验证环境变量是否生效
    if ! command -v mysql >/dev/null 2>&1; then
        print_warning "环境变量可能未生效"
    fi

    print_success "MySQL 环境变量已设置"
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

    # 检查数据目录是否存在
    if [ ! -d "$MYSQL_DATA_DIR" ]; then
        print_error "数据目录 $MYSQL_DATA_DIR 不存在，无法进行初始化"
        exit 1
    fi

    # 检查数据目录是否为空
    if [ "$(ls -A $MYSQL_DATA_DIR)" ]; then
        print_error "数据目录 $MYSQL_DATA_DIR 不为空，无法进行初始化"
        exit 1
    fi

    # 检查日志目录是否存在
    if [ ! -d "$MYSQL_LOG_DIR" ]; then
        print_error "日志目录 $MYSQL_LOG_DIR 不存在，无法进行初始化"
        exit 1
    fi

    # 检查 binlog 目录是否存在
    if [ ! -d "$MYSQL_BINLOG_DIR" ]; then
        print_error "binlog 目录 $MYSQL_BINLOG_DIR 不存在，无法进行初始化"
        exit 1
    fi

    # 检查 binlog 目录是否为空
    if [ "$(ls -A $MYSQL_BINLOG_DIR)" ]; then
        print_error "binlog 目录 $MYSQL_BINLOG_DIR 不为空，无法进行初始化"
        exit 1
    fi

    print_step "初始化 MySQL 数据库..."
    $MYSQL_INSTALL_DIR/bin/mysqld --defaults-file=$MYSQL_CONF_DIR/my.cnf --user=mysql --initialize
    if [ $? -ne 0 ]; then
        print_error "MySQL 数据库初始化失败"
        exit 1
    fi
    print_success "MySQL 数据库初始化成功"
}

# 启动 MySQL
mysql_install_start_service() {
    print_section "启动 MySQL 服务"
    print_step "启动 MySQL 服务..."
    $MYSQL_INSTALL_DIR/bin/mysqld_safe --defaults-file=$MYSQL_CONF_DIR/my.cnf --user=$MYSQL_USER &

    # 使用更短的间隔检查服务启动状态
    local max_attempts=10
    local attempt=1
    while [ $attempt -le $max_attempts ]; do
        print_step "等待服务启动 ($attempt/$max_attempts)..."
        if pgrep -x "mysqld" >/dev/null; then
            print_success "MySQL 服务已启动成功"
            return 0
        fi
        sleep 1
        ((attempt++))
    done

    print_error "MySQL 服务启动失败，请检查日志"
    exit 1
}

# 设置 root 密码
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

# 配置 MySQL 开机自启动服务
mysql_install_autostart_service() {
    print_section "配置 MySQL 开机自启动服务"

    # 获取当前脚本的进程 ID
    local current_script_pid=$$

    # 查找所有 mysqld 和 mysqld_safe 进程
    local mysql_pids=$(pgrep -x "mysqld|mysqld_safe")

    # 逐个检查并杀掉进程，避免误杀当前脚本
    for pid in $mysql_pids; do
        if [ "$pid" -ne "$current_script_pid" ]; then
            print_warning "正在杀掉 MySQL 进程 PID: $pid"
            kill -9 "$pid"
        else
            print_info "跳过当前脚本进程 PID: $pid"
        fi
    done

    sleep 2  # 确保进程完全退出

    print_step "创建 systemd 服务文件..."
    cat > /etc/systemd/system/mysql.service <<EOF
[Unit]
Description=MySQL Server
After=network.target

[Service]
Type=simple
User=mysql
Group=mysql

# 指定 PID 文件供 systemd 检查
PIDFile=/run/mysql/mysql.pid

# 使用 systemd 处理 /run/mysql 目录，避免手动创建失败
RuntimeDirectory=mysql
RuntimeDirectoryMode=0755

# 启动命令
ExecStart=$MYSQL_INSTALL_DIR/bin/mysqld_safe --defaults-file=$MYSQL_CONF_DIR/my.cnf --user=mysql

# 启动完成后输出消息
ExecStartPost=/bin/bash -c 'echo "MySQL Server started" | systemd-cat -t mysql'

# 停止命令
ExecStop=$MYSQL_INSTALL_DIR/bin/mysqladmin --defaults-file=$MYSQL_CONF_DIR/my.cnf --user=mysql shutdown

Restart=on-failure
RestartSec=5

# 资源限制
LimitNOFILE=65535
TimeoutSec=300

[Install]
WantedBy=multi-user.target
EOF

    print_step "重载 systemd 配置..."
    systemctl daemon-reload

    print_step "启用 MySQL 开机自启动..."
    systemctl enable mysql

    # 限制启动尝试次数，避免无限循环重启
    local start_attempts=0
    local max_start_attempts=3  # 最多尝试启动3次

    while [ $start_attempts -lt $max_start_attempts ]; do
        ((start_attempts++))
        print_step "尝试启动 MySQL 服务 (第 $start_attempts 次)..."

        print_debug "启动 MySQL 服务..."
        systemctl start mysql

        # 使用 systemctl is-active 服务是否启动成功
        print_debug "当前 MySQL 服务状态: $(systemctl is-active mysql)"

        # 等待 MySQL 服务完全启动
        local ready_attempts=0
        while ! mysqladmin ping -h127.0.0.1 --silent; do
            sleep 1
            ((ready_attempts++))
            if [ $ready_attempts -ge 30 ]; then
                print_error "MySQL 启动超时"
                exit 1
            fi
        done

        # 获取 MySQL 服务的状态
        local mysql_status=$(systemctl is-active mysql)

        # 如果服务是 active
        if [ "$mysql_status" == "active" ]; then
            print_success "MySQL 服务已启动成功"
            break
        else
            print_warning "第 $start_attempts 次启动尝试失败"
        fi

        if [ $start_attempts -lt $max_start_attempts ]; then
            print_step "等待 5 秒后进行下一次尝试..."
            sleep 5
        fi
    done
    print_success "MySQL 开机自启动服务配置成功"
}

# 验证 MySQL 安装
mysql_install_verify() {
    print_section "验证 MySQL 安装"

    # 1. 检查服务状态
    print_step "检查系统服务状态..."
    local mysql_status=$(systemctl is-active mysql)
    if [ "$mysql_status" != "active" ]; then
        print_error "MySQL 系统服务未正常运行"
        systemctl status mysql
        exit 1
    fi

    # 2. 检查开机自启动
    print_step "检查开机自启动状态..."
    local mysql_enable=$(systemctl is-enabled mysql)
    if [ "$mysql_enable" != "enabled" ]; then
        print_error "MySQL 未设置开机自启动"
        systemctl status mysql
        exit 1
    fi

    # 3. 检查数据库连接和基本操作
    print_step "验证数据库连接"
    local mysql_cmd="mysql -uroot -p$MYSQL_ROOT_PASSWORD"
    if ! $mysql_cmd --execute="SELECT VERSION();" >/dev/null 2>&1; then
        print_error "数据库连接失败"
        exit 1
    fi

    print_success "MySQL 安装验证全部通过！"
}

# 安装完成
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

    # 0.卸载旧的 mysql
    mysql_uninstall

    # 1. 前置检查
    mysql_common_check_disk
    mysql_common_check_mem
    mysql_common_check_dependencies
    mysql_common_check_processes

    # 2. 清理环境（使用统一的清理函数）
    mysql_common_cleanup

    # 3. 准备安装环境
    mysql_install_select_version
    mysql_install_create_user
    mysql_install_prepare_directories
    mysql_install_grant_user

    # 4. 下载和编译
    mysql_install_download_boost
    mysql_install_download_package
    mysql_install_compile

    # 5. 基础配置
    mysql_install_configure_cnf
    mysql_install_configure_path
    mysql_install_configure_cron
    mysql_install_configure_firewall

    # 6. 初始化和启动
    mysql_install_initialize
    mysql_install_start_service

    # 7. 设置 root 密码
    mysql_install_set_password

    # 8. 配置 MySQL 开机自启动服务
    mysql_install_autostart_service

    # 9. 验证完成
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
    print_info "6) MySQL"
    print_info "7) Exit"

    read -p "[$(date '+%Y-%m-%d %H:%M:%S')] [INPUT] - Please enter an option [1-7]: " software_choice

    case $software_choice in
        1) centos_repo_update ;;
        2) check_system_dependencies ;;
        3) manage_java ;;
        4) manage_maven ;;
        5) manage_redis ;;
        6) manage_mysql ;;
        7)
            print_info "Thank you for using this script. Goodbye!"
            exit 0
            ;;
        *)
            print_error "Invalid selection"
            exit 1
            ;;
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
