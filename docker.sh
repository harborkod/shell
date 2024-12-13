#!/bin/bash

# Docker 安装脚本
# 支持 CentOS 7/8
# 使用阿里云镜像源

# 变量定义
DOCKER_VERSION="24.0.7"  # Docker 版本
DOCKER_COMPOSE_VERSION="2.32.0"  # Docker Compose 版本
LOG_DIR="/var/log/docker_install"
LOG_FILE="$LOG_DIR/docker_install_$(date +%Y%m%d_%H%M%S).log"
ERROR_LOG="$LOG_DIR/docker_install_error_$(date +%Y%m%d_%H%M%S).log"
DOCKER_DATA_DIR="/var/lib/docker"
DOCKER_CONFIG_DIR="/etc/docker"
# 阿里云镜像加速器地址（需要替换为您的专属地址）
ALIYUN_MIRROR="https://YOUR_ID.mirror.aliyuncs.com"

# 定义退出码
readonly SUCCESS=0
readonly ERROR_ROOT_REQUIRED=1
readonly ERROR_OS_NOT_SUPPORTED=2
readonly ERROR_DEPENDENCY_INSTALL=3
readonly ERROR_DOCKER_INSTALL=4
readonly ERROR_DOCKER_START=5
readonly ERROR_COMPOSE_INSTALL=6

# 错误信息收集数组
declare -a ERROR_MESSAGES

# 捕获错误的函数
catch_error() {
    local exit_code=$?
    local line_number=$1
    local command=$2

    if [ $exit_code -ne 0 ]; then
        ERROR_MESSAGES+=("错误发生在第 $line_number 行: '$command' 执行失败，退出码: $exit_code")
        return $exit_code
    fi
}

# 设置错误捕获
trap 'catch_error ${LINENO} "$BASH_COMMAND"' ERR

# 显示所有错误信息
display_errors() {
    if [ ${#ERROR_MESSAGES[@]} -ne 0 ]; then
        echo "执行过程中发生以下错误："
        printf '%s\n' "${ERROR_MESSAGES[@]}"
    fi
}

# 日志函数
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" | tee -a "$LOG_FILE"

    # 如果是错误日志，同时写入错误日志文件
    if [ "$level" = "ERROR" ]; then
        echo "[$timestamp] [$level] $message" >> "$ERROR_LOG"
    fi
}

# 错误处理函数
handle_error() {
    local exit_code=$?
    local line_number=$1
    if [ $exit_code -ne 0 ]; then
        log "ERROR" "脚本执行失败在第 $line_number 行，错误代码: $exit_code"
        exit $exit_code
    fi
}

# 设置错误捕获
trap 'handle_error $LINENO' ERR

# 清理日志文件函数
cleanup_old_logs() {
    # 保留最近7天的日志
    find "$LOG_DIR" -name "docker_install_*.log" -mtime +7 -delete
}

# 开始安装提示
echo "-----------------------------开始 Docker 安装--------------------------------------"
start_time=$(date +%s)

# 检查是否为 root 用户
check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo "错误：此脚本需要 root 权限，请使用 root 用户执行或使用 sudo 命令。"
        exit $ERROR_ROOT_REQUIRED
    fi
}

# 检查系统版本
check_os() {
    local os_check_result=$SUCCESS
    echo "检查系统版本..."
    if [ -f /etc/centos-release ]; then
        OS_VERSION=$(cat /etc/centos-release | tr -dc '0-9.' | cut -d \. -f1)
        if [ "$OS_VERSION" != "7" ] && [ "$OS_VERSION" != "8" ]; then
            echo "错误：此脚本仅支持 CentOS 7/8"
            os_check_result=$ERROR_OS_NOT_SUPPORTED
        fi
    else
        echo "错误：此脚本仅支持 CentOS 系统"
        os_check_result=$ERROR_OS_NOT_SUPPORTED
    fi
    return $os_check_result
}

# 在 install_dependencies 函数前添加新的函数
check_and_fix_yum() {
    log "INFO" "检查 yum 源状态..."

    # 备份当前的 yum 源
    if [ ! -f /etc/yum.repos.d/CentOS-Base.repo.backup ]; then
        mv /etc/yum.repos.d/CentOS-Base.repo /etc/yum.repos.d/CentOS-Base.repo.backup 2>/dev/null
    fi

    # 下载新的 yum 源配置
    curl -o /etc/yum.repos.d/CentOS-Base.repo https://mirrors.aliyun.com/repo/Centos-7.repo

    # 清理并重建 yum 缓存
    yum clean all
    yum makecache
}

# 修改 install_dependencies 函数
install_dependencies() {
    local install_result=$SUCCESS
    local max_retries=3
    local retry_count=0

    log "INFO" "安装必要依赖..."

    # 更新 yum 缓存
    yum clean all
    yum makecache

    while [ $retry_count -lt $max_retries ]; do
        if yum install -y yum-utils device-mapper-persistent-data lvm2 \
            wget curl git vim net-tools bash-completion; then
            log "INFO" "依赖安装成功"
            return $SUCCESS
        else
            retry_count=$((retry_count + 1))
            log "WARN" "安装依赖失败，第 $retry_count 次重试..."
            sleep 5
        fi
    done

    log "ERROR" "安装依赖失败，已重试 $max_retries 次"
    return $ERROR_DEPENDENCY_INSTALL
}

# 停止并删除旧的 Docker
remove_old_docker() {
    log "INFO" "检查并删除旧版本 Docker..."

    # 停止 Docker 服务
    systemctl stop docker 2>/dev/null

    # 检查是否存在旧版本的 Docker 包
    local packages_to_remove=(
        docker
        docker-client
        docker-client-latest
        docker-common
        docker-latest
        docker-latest-logrotate
        docker-logrotate
        docker-engine
        docker-ce
        docker-ce-cli
        containerd.io
        docker-buildx-plugin
        docker-compose-plugin
    )
    
    local packages_found=()
    for package in "${packages_to_remove[@]}"; do
        if rpm -q "$package" &>/dev/null; then
            packages_found+=("$package")
        fi
    done

    # 只有在找到旧包的情况下才执行卸载
    if [ ${#packages_found[@]} -gt 0 ]; then
        log "INFO" "发现旧版本 Docker 包，开始卸载..."
        if ! yum remove -y "${packages_found[@]}" &>/dev/null; then
            log "WARN" "卸载旧版本时出现一些警告，继续安装..."
        fi
    else
        log "INFO" "未发现旧版本 Docker 包"
    fi

    # 清理旧的数据目录
    if [ -d "$DOCKER_DATA_DIR" ] || [ -d "$DOCKER_CONFIG_DIR" ]; then
        log "INFO" "清理旧的 Docker 数据目录..."
        rm -rf "$DOCKER_DATA_DIR"
        rm -rf "$DOCKER_CONFIG_DIR"
    fi

    log "INFO" "旧版本 Docker 清理完成"
}

# 修改 configure_docker_repo 函数
configure_docker_repo() {
    log "INFO" "配置 Docker 镜像源..."

    # 备份已存在的 Docker 源配置
    if [ -f /etc/yum.repos.d/docker-ce.repo ]; then
        mv /etc/yum.repos.d/docker-ce.repo /etc/yum.repos.d/docker-ce.repo.backup
    fi

    # 使用阿里云镜像源
    yum-config-manager --add-repo https://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo

    if [ $? -ne 0 ]; then
        log "ERROR" "添加 Docker 镜像源失败"
        return 1
    fi

    # 替换软件仓库地址
    sed -i 's+download.docker.com+mirrors.aliyun.com/docker-ce+' /etc/yum.repos.d/docker-ce.repo

    # 更新 yum 缓存
    yum makecache fast
}

# 安装 Docker
install_docker() {
    log "INFO" "开始安装 Docker..."
    yum install -y docker-ce-$DOCKER_VERSION docker-ce-cli-$DOCKER_VERSION containerd.io docker-buildx-plugin docker-compose-plugin
    if [ $? -ne 0 ]; then
        log "ERROR" "Docker 安装失败"
        exit 1
    fi
}

# 配置 Docker 守护进程
configure_docker_daemon() {
    log "INFO" "配置 Docker 守护进程..."
    mkdir -p "$DOCKER_CONFIG_DIR"

    # 创建 daemon.json 配置文件
    cat > "$DOCKER_CONFIG_DIR/daemon.json" <<EOF
{
    "registry-mirrors": [
        "https://hub-mirror.c.163.com",
        "https://mirror.baidubce.com",
        "https://mirror.ccs.tencentyun.com",
        "https://dockerhub.azk8s.cn",
        "https://docker.mirrors.ustc.edu.cn",
        "https://registry.docker-cn.com"
    ],
    "log-driver": "json-file",
    "log-opts": {
        "max-size": "100m",
        "max-file": "3"
    },
    "data-root": "$DOCKER_DATA_DIR",
    "exec-opts": ["native.cgroupdriver=systemd"],
    "storage-driver": "overlay2"
}
EOF
}

# 启动 Docker 服务
start_docker() {
    log "INFO" "启动 Docker 服务..."
    systemctl daemon-reload
    systemctl stop docker containerd
    rm -f /var/run/docker.sock
    systemctl start docker
    systemctl enable docker
    sleep 5
    if ! systemctl is-active docker &>/dev/null; then
        log "ERROR" "Docker 服务启动失败"
        log "DEBUG" "Docker 服务状态: $(systemctl status docker)"
        return 1
    fi
    log "INFO" "Docker 服务已启动并设置为开机自启"
}

# 安装 Docker Compose
install_docker_compose() {
    log "INFO" "安装 Docker Compose..."
    
    # 定义下载源
    local download_urls=(
        "https://harborkod.oss-rg-china-mainland.aliyuncs.com/arch/docker/docker-compose-linux-x86_64-v2.32.0"
        "https://github.com/docker/compose/releases/download/v${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)"
        "https://get.daocloud.io/docker/compose/releases/download/v${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)"
    )
    
    # 尝试每个下载源
    for url in "${download_urls[@]}"; do
        log "INFO" "尝试从 $url 下载..."
        if curl -L "$url" -o /usr/local/bin/docker-compose; then
            break
        else
            log "WARN" "从 $url 下载失败，尝试下一个源..."
        fi
    done

    # 检查文件是否成功下载
    if [ ! -f /usr/local/bin/docker-compose ]; then
        log "ERROR" "Docker Compose 文件不存在"
        return 1
    fi

    # 检查文件大小
    local file_size=$(stat -c%s "/usr/local/bin/docker-compose")
    if [ "$file_size" -lt 1000000 ]; then  # 文件小于 1MB 可能是下载不完整
        log "ERROR" "Docker Compose 文件似乎不完整（大小：$file_size 字��）"
        return 1
    fi

    log "INFO" "设置 Docker Compose 执行权限..."
    chmod +x /usr/local/bin/docker-compose
    if [ $? -ne 0 ]; then
        log "ERROR" "无法设置 Docker Compose 执行权限"
        return 1
    fi

    # 创建软链接
    log "INFO" "创建 Docker Compose 软链接..."
    ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose

    # 验证安装
    log "INFO" "验证 Docker Compose 安装..."
    if ! docker-compose --version >/dev/null 2>&1; then
        log "ERROR" "Docker Compose 命令执行失败"
        # 输出更多调试信息
        log "DEBUG" "文件权限: $(ls -l /usr/local/bin/docker-compose)"
        log "DEBUG" "文件类型: $(file /usr/local/bin/docker-compose)"
        log "DEBUG" "依赖库: $(ldd /usr/local/bin/docker-compose 2>&1)"
        return 1
    fi

    log "INFO" "Docker Compose 版本: $(docker-compose --version)"
    log "INFO" "Docker Compose 安装成功"
    return 0
}

# 配置用户组
configure_user_group() {
    log "INFO" "配置 Docker 用户组..."
    groupadd docker 2>/dev/null
    # 果当前用户不是 root，将其添加到 docker 组
    if [ "$SUDO_USER" ]; then
        usermod -aG docker $SUDO_USER
    fi
}

# 验证安装
verify_installation() {
    log "INFO" "验证 Docker 安装..."
    
    # 等待 Docker 服务完全启动
    local max_wait=30
    local count=0
    while ! docker info &>/dev/null && [ $count -lt $max_wait ]; do
        log "INFO" "等待 Docker 服务启动... ($count/$max_wait)"
        sleep 1
        count=$((count + 1))
    done

    if [ $count -eq $max_wait ]; then
        log "ERROR" "Docker 服务启动超时"
        return 1
    fi

    # 检查 Docker 服务状态
    if ! systemctl is-active docker &>/dev/null; then
        log "ERROR" "Docker 服务未运行"
        log "DEBUG" "Docker 服务状态: $(systemctl status docker)"
        return 1
    fi

    # 检查 Docker socket 权限
    if [ ! -S /var/run/docker.sock ]; then
        log "ERROR" "Docker socket 文件不存在"
        return 1
    fi

    # 验证 Docker 版本
    if ! docker --version; then
        log "ERROR" "无法获取 Docker 版本信息"
        return 1
    fi

    # 验证 Docker Compose 版本
    if ! docker-compose --version; then
        log "ERROR" "无法获取 Docker Compose 版本信息"
        return 1
    fi

    # 运行测试容器
    log "INFO" "运行测试容器..."
    if ! docker run --rm hello-world; then
        log "ERROR" "Docker 测试容器运行失败"
        log "DEBUG" "Docker 信息: $(docker info 2>&1)"
        log "DEBUG" "系统日志: $(journalctl -u docker --no-pager -n 50)"
        return 1
    fi

    log "INFO" "Docker 安装验证成功！"
    return 0
}

# 完成安装
finish_installation() {
    end_time=$(date +%s)
    execution_time=$((end_time - start_time))
    log "INFO" "-----------------------------Docker 安装完成--------------------------------------"
    log "INFO" "安装用时：${execution_time} 秒"
    log "INFO" "Docker 服务已启动并设置为开机自启"
    log "INFO" "Docker 配置文件位置：$DOCKER_CONFIG_DIR/daemon.json"
    log "INFO" "Docker 数据目录：$DOCKER_DATA_DIR"
    if [ "$SUDO_USER" ]; then
        log "INFO" "请注销并重新登录以应用 Docker 用户组更改"
    fi
}

# 在主函数开始前添加获取阿里云镜像地址的函数
get_aliyun_mirror() {
    local default_mirror="https://hub-mirror.c.163.com"

    echo "请输入阿里云镜像加速器地址（在阿里云控制台获取，直接回车将使用网易镜像）："
    read -r input_mirror

    if [ -z "$input_mirror" ]; then
        ALIYUN_MIRROR="$default_mirror"
        log "INFO" "使用默认镜像地址: $default_mirror"
    else
        ALIYUN_MIRROR="$input_mirror"
        log "INFO" "使用阿里云镜像���址: $input_mirror"
    fi
}

# 创建日志目录
create_log_dir() {
    if [ ! -d "$LOG_DIR" ]; then
        mkdir -p "$LOG_DIR"
        if [ $? -ne 0 ]; then
            echo "错误：无法创建日志目录 $LOG_DIR"
            exit 1
        fi
    fi
}

# 清理旧的安装和进程
cleanup_old_installation() {
    log "INFO" "清理旧的 Docker 安装环境..."

    # 停止所有运行中的容器
    if command -v docker &> /dev/null; then
        log "INFO" "停止所有运行中的容器..."
        docker ps -aq | xargs -r docker stop &> /dev/null
        docker ps -aq | xargs -r docker rm &> /dev/null
    fi

    # 停止 Docker 相关服务
    log "INFO" "停止 Docker 相关服务..."
    systemctl stop docker.socket &> /dev/null
    systemctl stop docker.service &> /dev/null
    systemctl stop containerd.service &> /dev/null

    # 卸载相关软件包
    log "INFO" "卸载 Docker 相关软件包..."
    yum remove -y docker \
        docker-client \
        docker-client-latest \
        docker-common \
        docker-latest \
        docker-latest-logrotate \
        docker-logrotate \
        docker-engine \
        docker-ce \
        docker-ce-cli \
        containerd.io \
        docker-buildx-plugin \
        docker-compose-plugin &> /dev/null

    # 删除相关文件和目录
    log "INFO" "清理 Docker 相关文件和目录..."
    rm -rf /var/lib/docker
    rm -rf /var/lib/containerd
    rm -rf /etc/docker
    rm -rf /etc/containerd
    rm -rf /var/run/docker*
    rm -rf /var/run/containerd
    rm -f /usr/local/bin/docker-compose

    # 清理网络接口
    log "INFO" "清理 Docker 网络接口..."
    ip link show | grep -E 'docker|br-|veth' | awk -F': ' '{print $2}' | cut -d'@' -f1 | while read -r iface; do
        ip link delete "$iface" &> /dev/null || true
    done

    # 清理 iptables 规则
    log "INFO" "清理 Docker iptables 规则..."
    iptables -t nat -F DOCKER || true
    iptables -t nat -X DOCKER || true
    iptables -t filter -F DOCKER || true
    iptables -t filter -X DOCKER || true
    iptables -t nat -F DOCKER-ISOLATION-STAGE-1 || true
    iptables -t nat -X DOCKER-ISOLATION-STAGE-1 || true
    iptables -t nat -F DOCKER-ISOLATION-STAGE-2 || true
    iptables -t nat -X DOCKER-ISOLATION-STAGE-2 || true

    # 清理用户组
    log "INFO" "清理 Docker 用户组..."
    if getent group docker > /dev/null; then
        groupdel docker &> /dev/null || true
    fi

    log "INFO" "环境清理完成"
}

# 显示帮助信息
show_help() {
    echo "用法: $0 [选项]"
    echo "选项:"
    echo "  -c, --clean    在安装前清理现有的 Docker 环境"
    echo "  -h, --help     显示此帮助信息"
    exit 0
}

# 解析命令行参数
CLEAN_INSTALL=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -c|--clean)
            CLEAN_INSTALL=true
            shift
            ;;
        -h|--help)
            show_help
            ;;
        *)
            echo "未知选项: $1"
            show_help
            ;;
    esac
done

# 主函数
main() {
    local exit_status=$SUCCESS

    # 创建日志目录
    create_log_dir

    check_root || {
        display_errors
        exit $?
    }

    check_os || {
        display_errors
        exit $?
    }

    # 如果指定了清理选项，则执行清理
    if [ "$CLEAN_INSTALL" = true ]; then
        cleanup_old_installation || {
            log "WARN" "环境清理过程中出现一些警告，继续安装..."
        }
    fi

    get_aliyun_mirror

    install_dependencies || {
        display_errors
        exit $?
    }

    remove_old_docker || {
        display_errors
        exit $?
    }

    configure_docker_repo || {
        display_errors
        exit $?
    }

    install_docker || {
        display_errors
        exit $ERROR_DOCKER_INSTALL
    }

    configure_docker_daemon || {
        display_errors
        exit $?
    }

    start_docker || {
        display_errors
        exit $ERROR_DOCKER_START
    }

    install_docker_compose || {
        display_errors
        exit $ERROR_COMPOSE_INSTALL
    }

    configure_user_group || {
        display_errors
        exit $?
    }

    verify_installation || {
        display_errors
        exit $?
    }

    finish_installation

    # 检查是否有错误发生
    if [ ${#ERROR_MESSAGES[@]} -ne 0 ]; then
        display_errors
        exit_status=1
    fi

    exit $exit_status
}

# 执行主程序
main

# 确保即使脚本被中断也显示错误信息
trap display_errors EXIT