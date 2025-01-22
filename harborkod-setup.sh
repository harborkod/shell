#!/bin/bash

# ==============================================
# HarborKod 软件安装管理工具
# 作者: harborkod
# 版本: 1.0.0
# ==============================================

# 全局配置
# ==============================================
# 是否开启调试模式 (true/false)
ENABLE_DEBUG=false

# 日志级别定义
LOG_DEBUG="DEBUG"
LOG_INFO="INFO"
LOG_WARN="WARN"
LOG_ERROR="ERROR"
LOG_SUCCESS="SUCCESS"

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

# 1. 通用配置和变量
# ======================
# 颜色代码
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

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
    install_dir="/usr/local/$jdk_version"

    # 添加调试信息
    print_debug "选择的版本信息: $selected"
    print_debug "名称: $name"
    print_debug "解析后的版本: $jdk_version"
    print_debug "解析后的下载URL: $download_url"
    print_debug "解析后的安装目录: $install_dir"

    print_success "已选择: $jdk_version"
}

jdk_install_cleanup_previous() {
    print_section "清理历史数据"
    download_dir="/opt"
    jdk_package="$download_dir/$(basename $download_url)"

    if [ -f "$jdk_package" ]; then
        print_step "清理已有安装包: $jdk_package"
        rm -f "$jdk_package"
        print_success "安装包清理完成"
    fi

    if [ -d "$install_dir" ]; then
        print_step "清理已有安装目录: $install_dir"
        rm -rf "$install_dir"
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

    if [ -x "$install_dir/bin/java" ]; then
        print_step "移除 java alternatives 配置"
        sudo $ALTERNATIVES_CMD --remove java "$install_dir/bin/java"
        print_success "Java alternatives 已清理"
    fi

    if [ -x "$install_dir/bin/javac" ]; then
        print_step "移除 javac alternatives 配置"
        sudo $ALTERNATIVES_CMD --remove javac "$install_dir/bin/javac"
        print_success "Javac alternatives 已清理"
    fi
}

jdk_install_download_package() {
    print_section "下载 JDK 安装包"
    
    # 打印调试信息
    print_debug "当前函数: ${FUNCNAME[0]}"
    print_debug "下载目录: $download_dir"
    print_debug "JDK 版本: $jdk_version"
    print_debug "下载 URL: $download_url"
    print_debug "安装包路径: $jdk_package"
    print_debug "安装目录: $install_dir"

    # 先确保 jdk_package 变量已正确设置
    if [ -z "$jdk_package" ]; then
        jdk_package="$download_dir/$(basename "$download_url")"
    fi
    print_step "下载文件将保存为: $jdk_package"

    # 检查下载目录
    if [ ! -d "$download_dir" ]; then
        print_step "创建下载目录: $download_dir"
        if ! mkdir -p "$download_dir"; then
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
            print_info "3. 是否有足够的磁盘空间: $(df -h $download_dir)"
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
    available_space=$(df "$download_dir" | tail -1 | awk '{print $4}')
    if [ "$available_space" -lt "$required_space" ]; then
        print_error "磁盘空间不足，需要至少 500MB 可用空间"
        exit 1
    fi

    if ! mkdir -p "$install_dir"; then
        print_error "创建安装目录失败，请检查权限"
        exit 1
    fi
    print_success "安装目录准备完成: $install_dir"
}

jdk_install_extract_package() {
    print_section "解压 JDK 安装包"
    print_step "正在解压: $jdk_package"
    
    case "$jdk_package" in
        *.tar.gz|*.tgz)
            if ! tar -xzf "$jdk_package" -C "$install_dir" --strip-components=1; then
                print_error "解压失败"
                exit 1
            fi
            ;;
        *.tar)
            if ! tar -xf "$jdk_package" -C "$install_dir" --strip-components=1; then
                print_error "解压失败"
                exit 1
            fi
            ;;
        *.zip)
            if ! unzip -q "$jdk_package" -d "$install_dir"; then
                print_error "解压失败"
                exit 1
            fi
            ;;
        *)
            print_error "不支持的压缩包格式"
            exit 1
            ;;
    esac

    if [ ! -d "$install_dir/bin" ]; then
        print_error "解压后未找到预期的目录结构"
        exit 1
    fi
    
    print_success "解压完成: $install_dir"
}

jdk_install_configure_env() {
    print_section "配置环境变量"
    
    env_file="/etc/profile.d/java_${jdk_version}.sh"
    print_step "创建环境变量配置文件"
    
    cat <<EOF | sudo tee "$env_file" >/dev/null
# Java 环境变量 - $jdk_version
export JAVA_HOME=$install_dir

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
    if [ ! -x "$install_dir/bin/java" ]; then
        print_error "Java 可执行文件不存在: $install_dir/bin/java"
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
    sudo $ALTERNATIVES_CMD --install /usr/bin/java java "$install_dir/bin/java" 2000 \
        --slave /usr/bin/javac javac "$install_dir/bin/javac" \
        --slave /usr/bin/jar jar "$install_dir/bin/jar" \
        --slave /usr/bin/jps jps "$install_dir/bin/jps"
    
    # 设置为默认版本
    print_step "设置为默认版本..."
    sudo $ALTERNATIVES_CMD --set java "$install_dir/bin/java"
    
    # 验证设置
    current_java=$($ALTERNATIVES_CMD --display java | grep "link currently points to" | awk '{print $NF}')
    
    if [ "$current_java" = "$install_dir/bin/java" ]; then
        print_success "已成功设置 $jdk_version 为默认版本"
    else
        print_warning "alternatives 配置可能未完全生效"
        print_step "创建直接链接..."
        sudo ln -sf "$install_dir/bin/java" /usr/bin/java
        sudo ln -sf "$install_dir/bin/javac" /usr/bin/javac
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
    print_info "安装路径: $install_dir"
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
    install_dir="/usr/local/$mvn_version"
    
    print_info "将安装: Apache Maven 3.8.7"
    print_debug "安装目录: $install_dir"
    print_debug "下载地址: $download_url"
}

mvn_install_cleanup_previous() {
    print_section "清理历史数据"
    download_dir="/opt"
    mvn_package="$download_dir/$(basename $download_url)"

    if [ -f "$mvn_package" ]; then
        print_step "清理已有安装包: $mvn_package"
        rm -f "$mvn_package"
        print_success "安装包清理完成"
    fi

    if [ -d "$install_dir" ]; then
        print_step "清理已有安装目录: $install_dir"
        rm -rf "$install_dir"
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
    print_debug "下载目录: $download_dir"
    print_debug "Maven 版本: $mvn_version"
    print_debug "下载 URL: $download_url"
    print_debug "安装包路径: $mvn_package"
    print_debug "安装目录: $install_dir"

    # 先确保 mvn_package 变量已正确设置
    if [ -z "$mvn_package" ]; then
        mvn_package="$download_dir/$(basename "$download_url")"
    fi
    print_step "下载文件将保存为: $mvn_package"

    # 检查下载目录
    if [ ! -d "$download_dir" ]; then
        print_step "创建下载目录: $download_dir"
        if ! mkdir -p "$download_dir"; then
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
            print_info "3. 是否有足够的磁盘空间: $(df -h $download_dir)"
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
}

mvn_install_prepare_directory() {
    print_section "准备安装目录"
    
    required_space=50000  # Maven 需要的空间比 JDK 小
    available_space=$(df "$download_dir" | tail -1 | awk '{print $4}')
    if [ "$available_space" -lt "$required_space" ]; then
        print_error "磁盘空间不足，需要至少 50MB 可用空间"
        exit 1
    fi

    if ! mkdir -p "$install_dir"; then
        print_error "创建安装目录失败，请检查权限"
        exit 1
    fi
    print_success "安装目录准备完成: $install_dir"
}

mvn_install_extract_package() {
    print_section "解压 Maven 安装包"
    print_step "正在解压: $mvn_package"
    
    if ! tar -xzf "$mvn_package" -C "$install_dir" --strip-components=1; then
        print_error "解压失败"
        exit 1
    fi

    if [ ! -d "$install_dir/bin" ]; then
        print_error "解压后未找到预期的目录结构"
        exit 1
    fi
    
    print_success "解压完成: $install_dir"
}

mvn_install_configure_env() {
    print_section "配置环境变量"
    
    env_file="/etc/profile.d/maven_${mvn_version}.sh"
    print_step "创建环境变量配置文件"
    
    cat <<EOF | sudo tee "$env_file" >/dev/null
# Maven 环境变量 - $mvn_version
export MAVEN_HOME=$install_dir

# 确保 PATH 中不会重复添加 MAVEN_HOME/bin
if [[ ":\$PATH:" != *":\$MAVEN_HOME/bin:"* ]]; then
    export PATH=\$PATH:\$MAVEN_HOME/bin
fi
EOF

    if [ $? -ne 0 ]; then
        print_error "环境变量配置失败"
        exit 1
    fi

    source "$env_file"
    print_success "环境变量配置完成: $env_file"
}

mvn_install_verify() {
    print_section "验证安装结果"
    
    source "/etc/profile.d/maven_${mvn_version}.sh"
    
    if [ -x "$MAVEN_HOME/bin/mvn" ]; then
        print_success "Maven 安装成功"
        print_info "版本信息如下:"
        "$MAVEN_HOME/bin/mvn" -version | while IFS= read -r line; do
            print_info "$line"
        done
    else
        print_error "Maven 安装失败"
        print_warning "请运行: source /etc/profile.d/maven_${mvn_version}.sh"
        exit 1
    fi
}

mvn_install_finish() {
    end_time=$(date +%s)
    execution_time=$((end_time - start_time))
    
    print_section "安装完成"
    print_success "Maven 安装成功"
    print_info "安装用时: ${execution_time} 秒"
    print_info "Maven 版本: $($MAVEN_HOME/bin/mvn -version | head -n 1)"
    print_info "安装路径: $install_dir"
    print_warning "请执行以下命令使环境变量生效:"
    print_info "source /etc/profile.d/maven_${mvn_version}.sh"
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
    mvn_install_configure_env
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
    
    print_info "开始清理环境变量..."
    mvn_uninstall_remove_env_files
    mvn_uninstall_remove_installation
    mvn_uninstall_remove_downloads
    mvn_uninstall_cleanup_env_vars
    mvn_uninstall_finish
}





# 5. MySQL 相关函数
# ======================
mysql_install() {
    # MySQL 安装主函数
    return 0
}

mysql_uninstall() {
    # MySQL 卸载主函数
    return 0
}

# 6. 菜单管理函数
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
    print_section "MySQL 管理"
    # ... MySQL 管理菜单
}

select_software() {
    print_section "选择软件"
    print_info "请选择要管理的软件:"
    print_info "1) Java (JDK)"
    print_info "2) Maven"
    print_info "3) MySQL"
    print_info "4) 退出"
    
    read -p "[$(date '+%Y-%m-%d %H:%M:%S')] [INPUT] - 请输入选项 [1-4]: " software_choice

    case $software_choice in
        1)
            manage_java
            ;;
        2)
            manage_maven
            ;;
        3)
            manage_mysql
            ;;
        4)
            print_info "感谢使用，再见！"
            exit 0
            ;;
        *)
            print_error "无效的选择"
            exit 1
            ;;
    esac
}

# 7. 主函数
# ======================
main() {
    print_info "HarborKod 软件安装管理工具"
    print_info "作者: harborkod"
    print_info "版本: 1.0.0"
    select_software
}

# 执行主函数
main 
