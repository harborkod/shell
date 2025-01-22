#!/bin/bash

# 在文件开头添加日志格式化函数
print_section() {
    local title="$1"
    echo ""
    echo "┌──────────────────────────────────────────────────────────────┐"
    echo "│                      $title"
    echo "└──────────────────────────────────────────────────────────────┘"
}

print_step() {
    local message="$1"
    echo "  → $message"
}

print_success() {
    local message="$1"
    echo "  ✔ $message"
}

print_error() {
    local message="$1"
    echo "  ✘ $message"
}

print_warning() {
    local message="$1"
    echo "  ⚠ $message"
}

print_info() {
    local message="$1"
    echo "  ℹ $message"
}

# 输出开始安装的提示信息
echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║                     Java 安装程序启动                           ║"
echo "║                     作者: harborkod                            ║"
echo "║                     版本: 1.0.0                                ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
start_time=$(date +%s)

# 检查依赖
check_dependencies() {
    print_section "检查系统依赖"
    # 检查是否具有 sudo 权限
    if [ "$EUID" -ne 0 ] && ! command -v sudo >/dev/null 2>&1; then
        print_error "此脚本需要 root 权限或 sudo 命令"
        exit 1
    fi

    # 检查 tar、wget 和 unzip
    for cmd in tar wget unzip; do
        if ! command -v $cmd >/dev/null 2>&1; then
            print_warning "未检测到 $cmd 命令，正在安装 $cmd..."
            if command -v yum >/dev/null 2>&1; then
                sudo yum install -y $cmd
                print_success "$cmd 安装完成"
            elif command -v apt-get >/dev/null 2>&1; then
                sudo apt-get install -y $cmd
                print_success "$cmd 安装完成"
            else
                print_error "无法自动安装 $cmd，请手动安装"
                exit 1
            fi
        else
            print_success "$cmd 已安装"
        fi
    done
}

# 检查现有的 Java 安装
check_existing_java() {
    print_section "检查现有 Java 安装"
    if command -v java >/dev/null 2>&1; then
        print_info "检测到已安装的 Java 版本："
        java -version 2>&1
        
        if java -version 2>&1 | grep -i "openjdk" >/dev/null; then
            print_warning "检测到系统已安装 OpenJDK"
            read -p "  是否要卸载现有的 OpenJDK 后继续安装？(y/n): " remove_choice
            if [ "$remove_choice" = "y" ] || [ "$remove_choice" = "Y" ]; then
                print_step "正在卸载 OpenJDK..."
                if command -v yum >/dev/null 2>&1; then
                    sudo yum remove -y java-* java-*-openjdk-* java-*-openjdk-headless
                elif command -v apt-get >/dev/null 2>&1; then
                    sudo apt-get remove -y openjdk* java*
                    sudo apt-get autoremove -y
                else
                    print_error "无法自动卸载 OpenJDK，请手动卸载后再运行此脚本"
                    exit 1
                fi
                print_success "OpenJDK 已成功卸载"
            else
                print_info "用户选择保留现有 Java 安装"
                exit 0
            fi
        else
            print_warning "检测到已安装其他版本的 Java"
            read -p "  是否继续安装新版本？(y/n): " continue_choice
            if [ "$continue_choice" != "y" ] && [ "$continue_choice" != "Y" ]; then
                print_info "用户选择不继续安装"
                exit 0
            fi
        fi
    else
        print_info "未检测到已安装的 Java"
    fi
}

# 在 select_java_version 函数前添加卸载选项
select_operation() {
    print_section "选择操作"
    echo "  可用操作:"
    echo "    1) 安装 Java"
    echo "    2) 卸载 Java"
    echo ""
    read -p "  请选择操作 [1-2]: " operation_choice

    case $operation_choice in
        1)
            print_success "已选择: 安装 Java"
            return 0
            ;;
        2)
            uninstall_java
            exit 0
            ;;
        *)
            print_error "无效的选择"
            exit 1
            ;;
    esac
}

# 添加卸载函数
uninstall_java() {
    print_section "开始卸载 Java"
    
    # 检查系统自带的 OpenJDK
    if command -v java >/dev/null 2>&1; then
        print_info "检测到已安装的 Java 版本："
        java -version 2>&1 | while read -r line; do
            echo "    $line"
        done
        
        # 卸载系统 OpenJDK
        if java -version 2>&1 | grep -i "openjdk" >/dev/null; then
            print_step "卸载系统 OpenJDK..."
            if command -v yum >/dev/null 2>&1; then
                sudo yum remove -y java-* java-*-openjdk-* java-*-openjdk-headless
            elif command -v apt-get >/dev/null 2>&1; then
                sudo apt-get remove -y openjdk* java*
                sudo apt-get autoremove -y
            fi
            print_success "系统 OpenJDK 已卸载"
        fi
    fi

    # 清理通过脚本安装的 Java
    print_step "清理脚本安装的 Java..."
    
    # 清理 alternatives
    if command -v update-alternatives >/dev/null 2>&1; then
        ALTERNATIVES_CMD="update-alternatives"
    elif command -v alternatives >/dev/null 2>&1; then
        ALTERNATIVES_CMD="alternatives"
    fi

    if [ -n "$ALTERNATIVES_CMD" ]; then
        print_step "清理 alternatives 配置..."
        sudo $ALTERNATIVES_CMD --remove-all java 2>/dev/null
        sudo $ALTERNATIVES_CMD --remove-all javac 2>/dev/null
        print_success "Alternatives 配置已清理"
    fi

    # 清理环境变量文件
    print_step "清理环境变量配置..."
    for env_file in /etc/profile.d/java_*.sh; do
        if [ -f "$env_file" ]; then
            sudo rm -f "$env_file"
            print_success "已删除环境变量文件: $env_file"
        fi
    done

    # 清理安装目录
    print_step "清理安装目录..."
    local java_dirs=("/usr/local/jdk*" "/usr/local/java*" "/usr/local/openjdk*")
    for dir_pattern in "${java_dirs[@]}"; do
        for dir in $dir_pattern; do
            if [ -d "$dir" ]; then
                sudo rm -rf "$dir"
                print_success "已删除目录: $dir"
            fi
        done
    done

    # 清理下载文件
    print_step "清理下载文件..."
    for file in /opt/jdk*.tar.gz /opt/openjdk*.tar.gz; do
        if [ -f "$file" ]; then
            sudo rm -f "$file"
            print_success "已删除文件: $file"
        fi
    done

    # 清理 JAVA_HOME 环境变量
    print_step "清理当前会话的环境变量..."
    unset JAVA_HOME
    
    print_success "Java 卸载完成"
    print_warning "请执行以下命令使环境变量生效:"
    echo "    source /etc/profile"
    echo ""
    print_info "如需重新安装 Java，请重新运行此脚本"
}

# 显示 Java 版本选择菜单
select_java_version() {
    print_section "选择 Java 版本"
    echo "  可用版本:"
    echo "    1) Oracle JDK 8u421"
    echo "    2) OpenJDK 11.0.2"
    echo "    3) OpenJDK 17.0.2"
    echo ""
    read -p "  请选择版本 [1-3]: " choice

    case $choice in
        1)
            jdk_version="jdk-8u421"
            download_url="https://harborkod.oss-rg-china-mainland.aliyuncs.com/arch/java/jdk-8u421-linux-x64.tar.gz"
            ;;
        2)
            jdk_version="openjdk-11.0.2"
            download_url="https://mirrors.huaweicloud.com/openjdk/11.0.2/openjdk-11.0.2_linux-x64_bin.tar.gz"
            ;;
        3)
            jdk_version="openjdk-17.0.2"
            download_url="https://mirrors.huaweicloud.com/openjdk/17.0.2/openjdk-17.0.2_linux-x64_bin.tar.gz"
            ;;
        *)
            print_error "无效的选择"
            exit 1
            ;;
    esac
    print_success "已选择: $jdk_version"
}

# 清理旧的安装包、安装目录和 alternatives 条目
cleanup_previous_installation() {
    print_section "清理历史数据"
    download_dir="/opt"
    jdk_package="$download_dir/$(basename $download_url)"

    if [ -f "$jdk_package" ]; then
        print_step "清理已有安装包: $jdk_package"
        rm -f "$jdk_package"
        print_success "安装包清理完成"
    fi

    install_dir="/usr/local/$jdk_version"
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

    cleanup_alternatives
}

# 清理 alternatives 条目
cleanup_alternatives() {
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

# 下载 JDK 安装包
download_jdk_package() {
    print_section "下载 JDK 安装包"
    
    if ! ping -c 1 -W 3 $(echo $download_url | awk -F/ '{print $3}') >/dev/null 2>&1; then
        print_error "无法连接到下载服务器，请检查网络连接"
        exit 1
    fi

    print_step "开始下载 $jdk_version"
    for i in {1..3}; do
        if wget -P "$download_dir" "$download_url"; then
            print_success "下载完成: $jdk_package"
            break
        else
            print_warning "下载失败，第 $i 次重试..."
            sleep 2
        fi
        if [ $i -eq 3 ]; then
            print_error "下载失败，请检查网络连接"
            exit 1
        fi
    done
}

# 创建安装目录
prepare_installation_directory() {
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

# 解压 JDK 安装包
extract_jdk_package() {
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

# 配置环境变量
configure_environment_variables() {
    print_section "配置环境变量"
    
    env_file="/etc/profile.d/java_${jdk_version}.sh"
    print_step "创建环境变量配置文件"
    
    cat <<EOF | sudo tee "$env_file" >/dev/null
# Java 环境变量 - $jdk_version
export JAVA_HOME=$install_dir
export PATH=\$PATH:\${JAVA_HOME}/bin
EOF

    if [ $? -ne 0 ]; then
        print_error "环境变量配置失败"
        exit 1
    fi

    source "$env_file"
    print_success "环境变量配置完成: $env_file"
}

# 设置默认的 Java 版本
set_default_java() {
    print_section "配置默认 Java 版本"
    
    if command -v update-alternatives >/dev/null 2>&1; then
        ALTERNATIVES_CMD="update-alternatives"
    elif command -v alternatives >/dev/null 2>&1; then
        ALTERNATIVES_CMD="alternatives"
    else
        print_warning "未找到 alternatives 命令，跳过配置"
        return
    fi

    if [ ! -x "$install_dir/bin/java" ]; then
        print_error "Java 可执行文件不存在: $install_dir/bin/java"
        exit 1
    fi

    print_step "配置 Java alternatives"
    sudo $ALTERNATIVES_CMD --install /usr/bin/java java "$install_dir/bin/java" 100
    sudo $ALTERNATIVES_CMD --install /usr/bin/javac javac "$install_dir/bin/javac" 100

    if [ $? -ne 0 ]; then
        print_error "Alternatives 配置失败"
        exit 1
    fi

    sudo $ALTERNATIVES_CMD --set java "$install_dir/bin/java"
    sudo $ALTERNATIVES_CMD --set javac "$install_dir/bin/javac"
    print_success "已设置 $jdk_version 为默认版本"
}

# 检查 Java 版本
verify_installation() {
    print_section "验证安装结果"
    if command -v java >/dev/null 2>&1; then
        print_success "Java 安装成功"
        print_info "版本信息:"
        java -version 2>&1 | while read -r line; do
            echo "    $line"
        done
    else
        print_error "Java 安装失败"
        print_warning "请运行: source /etc/profile.d/java_${jdk_version}.sh"
        exit 1
    fi
}

# 完成安装
finish_installation() {
    end_time=$(date +%s)
    execution_time=$((end_time - start_time))
    
    echo ""
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║                        安装完成                                ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo ""
    print_success "Java 安装成功"
    print_info "安装用时: ${execution_time} 秒"
    print_info "Java 版本: $(java -version 2>&1 | head -n 1)"
    print_info "安装路径: $install_dir"
    echo ""
    print_warning "请执行以下命令使环境变量生效:"
    echo "    source /etc/profile.d/java_${jdk_version}.sh"
    echo ""
}

# 修改主程序，添加操作选择
main() {
    check_dependencies
    select_operation
    check_existing_java
    select_java_version
    cleanup_previous_installation
    download_jdk_package
    prepare_installation_directory
    extract_jdk_package
    configure_environment_variables
    set_default_java
    verify_installation
    finish_installation
}

# 调用主程序
main
