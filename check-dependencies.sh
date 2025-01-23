#!/bin/bash

# ==============================================
# 日志打印函数
# ==============================================
print_section() {
    echo -e "\n[$(date '+%Y-%m-%d %H:%M:%S')] [SECTION] - $1"
    echo "============================================================"
}

print_step() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [STEP] - $1"
}

print_info() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] - $1"
}

print_warning() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [WARNING] - $1" >&2
}

print_error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] - $1" >&2
}

print_success() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [SUCCESS] - $1"
}

# ==============================================
# 依赖检查函数
# ==============================================
check_root_permission() {
    if [ "$EUID" -ne 0 ] && ! command -v sudo >/dev/null 2>&1; then
        print_error "此脚本需要 root 权限或 sudo 命令"
        return 1
    fi
    return 0
}

install_package() {
    local package=$1
    if command -v yum >/dev/null 2>&1; then
        sudo yum install -y "$package"
    elif command -v apt-get >/dev/null 2>&1; then
        sudo apt-get update
        sudo apt-get install -y "$package"
    elif command -v dnf >/dev/null 2>&1; then
        sudo dnf install -y "$package"
    else
        print_error "无法找到包管理器（yum/apt-get/dnf），请手动安装 $package"
        return 1
    fi
    return 0
}

check_and_install_dependency() {
    local cmd=$1
    local package=${2:-$cmd}
    
    if ! command -v "$cmd" >/dev/null 2>&1; then
        print_warning "未检测到 $cmd 命令，正在安装..."
        if install_package "$package"; then
            print_success "$package 安装完成"
        else
            print_error "$package 安装失败"
            return 1
        fi
    else
        print_success "$cmd 已安装"
    fi
    return 0
}

check_dependencies() {
    print_section "检查系统依赖"
    
    # 检查 root 权限
    if ! check_root_permission; then
        exit 1
    fi

    # 定义依赖项及其对应的包名（如果不同的话）
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
    )

    # 检查每个依赖
    for cmd in "${!dependencies[@]}"; do
        if ! check_and_install_dependency "$cmd" "${dependencies[$cmd]}"; then
            print_error "依赖检查失败"
            exit 1
        fi
    done

    print_success "所有依赖检查完成"
}

# ==============================================
# 主函数
# ==============================================
main() {
    check_dependencies
}

# 如果直接运行此脚本，则执行主函数
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi 