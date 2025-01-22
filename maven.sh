#!/bin/bash

# 定义颜色代码
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Jenkins 版本和安装目录
MAVEN_VERSION="3.8.7"
MAVEN_SOURCE_URL="https://harborkod.oss-rg-china-mainland.aliyuncs.com/arch/maven/apache-maven-3.8.7-bin.tar.gz"
DOWNLOAD_DIR="/opt"
INSTALL_DIR="/usr/local/apache-maven-3.8.7"
LOCAL_REPO="/repo"  
MAVEN_USER="maven"
MAVEN_GROUP="maven"

# 格式化输出函数
print_header() {
    clear
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                    ${BOLD}Maven 安装管理工具${NC}${CYAN}                   ║${NC}"
    echo -e "${CYAN}║                    作者: harborkod                          ║${NC}"
    echo -e "${CYAN}║                    版本: 1.0.0                             ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_section() {
    local title="$1"
    local title_length=${#title}
    local padding=$(( (44 - title_length) / 2 ))
    echo ""
    echo -e "${BLUE}┌──────────────────────────────────────────────────────────┐${NC}"
    printf "${BLUE}│${NC}%${padding}s${BOLD}%s${NC}%${padding}s${BLUE}│${NC}\n" "" "$title" ""
    echo -e "${BLUE}└──────────────────────────────────────────────────────────┘${NC}"
}

print_step() {
    local message="$1"
    echo -e "${CYAN}  →${NC} $message"
}

print_success() {
    local message="$1"
    echo -e "${GREEN}  ✔${NC} $message"
}

print_error() {
    local message="$1"
    echo -e "${RED}  ✘${NC} $message"
}

print_warning() {
    local message="$1"
    echo -e "${YELLOW}  ⚠${NC} $message"
}

print_info() {
    local message="$1"
    echo -e "${BLUE}  ℹ${NC} $message"
}

print_divider() {
    echo -e "${BLUE}  ─────────────────────────────────────────────────────────${NC}"
}

print_menu_item() {
    local number="$1"
    local description="$2"
    echo -e "    ${CYAN}${number}${NC}) ${description}"
}

# 选择操作
select_operation() {
    print_section "选择操作"
    echo "  请选择要执行的操作:"
    print_divider
    print_menu_item "1" "安装 Maven"
    print_menu_item "2" "卸载 Maven"
    echo ""
    read -p "  请输入选项 [1-2]: " operation_choice
    echo ""

    case $operation_choice in
        1)
            print_success "已选择: 安装 Maven"
            install_maven
            ;;
        2)
            print_success "已选择: 卸载 Maven"
            uninstall_maven
            ;;
        *)
            print_error "无效的选择"
            exit 1
            ;;
    esac
}

# 清理 PATH 中的 Maven 相关路径
cleanup_path() {
    # 保存原始 IFS
    local OIFS="$IFS"
    IFS=':'
    
    # 将 PATH 转换为数组
    local -a paths=($PATH)
    # 创建关联数组用于去重
    declare -A unique_paths
    
    # 清理后的 PATH
    local new_path=""
    
    # 遍历所有路径
    for p in "${paths[@]}"; do
        # 跳过包含 maven 的路径
        if [[ "$p" != *"maven"* ]]; then
            # 只添加不重复的路径
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
    
    # 恢复原始 IFS
    IFS="$OIFS"
    
    # 导出新的 PATH
    export PATH="$new_path"
}

# 卸载 Maven
uninstall_maven() {
    print_section "开始卸载 Maven"

    # 检查并终止 Maven 进程
    print_step "检查 Maven 进程..."
    local maven_processes=$(ps -ef | grep maven | grep -v grep | grep -v $$ | awk '{print $2}')
    if [ -n "$maven_processes" ]; then
        print_warning "检测到正在运行的 Maven 进程"
        for pid in $maven_processes; do
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

    # 删除安装目录
    if [ -d "$INSTALL_DIR" ]; then
        print_step "删除安装目录..."
        rm -rf "$INSTALL_DIR"
        print_success "已删除安装目录: $INSTALL_DIR"
    fi

    # 清理环境变量
    print_step "清理环境变量..."
    local env_file="/etc/profile.d/maven.sh"
    if [ -f "$env_file" ]; then
        if rm -f "$env_file"; then
            print_success "已删除环境变量配置文件"
        else
            print_error "删除环境变量配置文件失败"
        fi
    fi

    # 清理当前会话的环境变量
    print_step "清理当前会话的环境变量..."
    unset MAVEN_HOME
    unset M2_HOME
    cleanup_path
    print_success "当前会话的环境变量已清理"

    # 清理本地仓库（可选）
    if [ -d "$LOCAL_REPO" ]; then
        print_warning "检测到 Maven 本地仓库: $LOCAL_REPO"
        read -p "  是否删除本地仓库？(y/n): " remove_repo
        if [ "$remove_repo" = "y" ] || [ "$remove_repo" = "Y" ]; then
            rm -rf "$LOCAL_REPO"
            print_success "已删除本地仓库"
        else
            print_info "保留本地仓库"
        fi
    fi

    # 删除用户和用户组
    if id "$MAVEN_USER" >/dev/null 2>&1; then
        print_step "删除 Maven 用户..."
        userdel -r "$MAVEN_USER" 2>/dev/null
        print_success "已删除用户: $MAVEN_USER"
    fi

    if getent group "$MAVEN_GROUP" >/dev/null; then
        print_step "删除 Maven 用户组..."
        groupdel "$MAVEN_GROUP" 2>/dev/null
        print_success "已删除用户组: $MAVEN_GROUP"
    fi

    print_success "Maven 卸载完成"
    echo ""
    print_warning "请执行以下命令使环境变量生效:"
    echo "    source /etc/profile"
    echo ""
}

# 安装 Maven
install_maven() {
    validate_process
    clearOldData
    downloadSourcePackage
    modifySettingFile
    addEnvPath
    createMavenUser
    validateInstallResult
}

# 1. 提示
prompt(){
    echo "-----------------------------开始 Maven 安装--------------------------------------"
}

# 2. 进程校验（判断是否有maven进程）
validate_process(){
    print_section "检查 Maven 进程"
    print_step "检查是否有正在运行的 Maven 进程..."
    
    local maven_processes=$(ps -ef | grep maven | grep -v grep | grep -v $$ | awk '{print $2}')
    if [ -n "$maven_processes" ]; then
        print_warning "检测到正在运行的 Maven 进程"
        for pid in $maven_processes; do
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

# 3. 清理旧数据（源码包、安装目录、环境变量配置）
clearOldData(){
    print_section "清理历史数据"
    
    # 3.1 清理源码包
    print_step "清理 Maven 源码包..."
    if [ -f "$INSTALL_DIR/apache-maven-$MAVEN_VERSION-bin.tar.gz" ]; then
        rm -f "$INSTALL_DIR/apache-maven-$MAVEN_VERSION-bin.tar.gz"
        print_success "已删除源码包: $INSTALL_DIR/apache-maven-$MAVEN_VERSION-bin.tar.gz"
    fi

    # 3.2 清理安装目录
    print_step "清理安装目录..."
    if [ -d "$INSTALL_DIR" ]; then
        rm -rf "$INSTALL_DIR"
        print_success "已删除安装目录: $INSTALL_DIR"
    fi

    # 3.3 清理环境变量配置
    ENV_FILE="/etc/profile.d/maven.sh"
    print_step "清理环境变量配置..."
    if [ -f "$ENV_FILE" ]; then
        rm -f "$ENV_FILE"
        print_success "已删除环境变量配置: $ENV_FILE"
    fi
}

# 4. 下载并解压源码包
downloadSourcePackage(){
    print_section "下载并解压 Maven"
    
    # 4.1 磁盘空间检测
    print_step "检查磁盘空间..."
    AVAILABLE_SPACE=$(df /usr/local | tail -1 | awk '{print $4}')
    if [ "$AVAILABLE_SPACE" -lt 5000000 ]; then
        print_error "磁盘空间不足，至少需要 5GB 可用空间"
        exit 1
    fi
    print_success "磁盘空间充足"

    # 4.2 下载源码
    print_step "开始下载 Maven $MAVEN_VERSION"
    cd $DOWNLOAD_DIR
    if [ -f "apache-maven-$MAVEN_VERSION-bin.tar.gz" ]; then
        print_info "Maven 源码包已存在，跳过下载"
    else
        if ! wget -O apache-maven-$MAVEN_VERSION-bin.tar.gz $MAVEN_SOURCE_URL; then
            print_error "下载 Maven 源码包失败"
            exit 1
        fi
        print_success "下载完成"
    fi

    # 4.3 验证 SHA-512 校验码
    print_step "验证文件完整性..."
    EXPECTED_CHECKSUM="21c2be0a180a326353e8f6d12289f74bc7cd53080305f05358936f3a1b6dd4d91203f4cc799e81761cf5c53c5bbe9dcc13bdb27ec8f57ecf21b2f9ceec3c8d27"
    ACTUAL_CHECKSUM=$(sha512sum apache-maven-$MAVEN_VERSION-bin.tar.gz | awk '{ print $1 }')
    if [ "$EXPECTED_CHECKSUM" != "$ACTUAL_CHECKSUM" ]; then
        print_error "文件校验失败，下载的文件可能已损坏"
        exit 1
    fi
    print_success "文件校验通过"

    # 4.4 解压
    print_step "解压源码包..."
    if ! tar -zxf apache-maven-$MAVEN_VERSION-bin.tar.gz -C /usr/local; then
        print_error "解压失败"
        exit 1
    fi
    print_success "解压完成"
}

# 5. 修改配置文件
modifySettingFile(){
    print_section "配置 Maven"
    
    # 5.1 磁盘空间检测
    print_step "检查本地仓库所需空间..."
    AVAILABLE_SPACE_ROOT=$(df / | tail -1 | awk '{print $4}')
    if [ "$AVAILABLE_SPACE_ROOT" -lt 10000000 ]; then
        print_error "磁盘空间不足，至少需要 10GB 可用空间"
        exit 1
    fi
    print_success "磁盘空间充足"

    # 5.2 设置本地仓库
    print_step "配置本地仓库..."
    if [ ! -d "$LOCAL_REPO" ]; then
        mkdir -p "$LOCAL_REPO"
        print_success "创建本地仓库目录: $LOCAL_REPO"
    fi

    # 5.3 备份原始配置文件
    SETTINGS_FILE="$INSTALL_DIR/conf/settings.xml"
    print_step "备份原始配置..."
    cp "$SETTINGS_FILE" "$SETTINGS_FILE.bak"
    print_success "已备份配置文件到: $SETTINGS_FILE.bak"

    # 5.4 更新配置文件
    print_step "更新 Maven 配置..."
    cat <<EOL > "$SETTINGS_FILE"
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

# 6. 设置环境变量
addEnvPath(){
    print_section "配置环境变量"
    
    # 6.1 设置 Maven 环境变量
    ENV_FILE="/etc/profile.d/maven.sh"
    print_step "创建环境变量配置..."
    
    # 先清理已存在的 Maven 路径
    cleanup_path
    
    # 检查环境变量文件是否存在
    if [ -f "$ENV_FILE" ]; then
        print_step "检查现有环境变量配置..."
        if grep -q "MAVEN_HOME=$INSTALL_DIR" "$ENV_FILE" && \
           grep -q "M2_HOME=$INSTALL_DIR" "$ENV_FILE"; then
            print_info "Maven 环境变量已正确配置，无需更改"
            return 0
        else
            print_warning "发现旧的环境变量配置，进行更新..."
            rm -f "$ENV_FILE"
        fi
    fi

    # 创建新的环境变量配置
    cat <<EOF > "$ENV_FILE"
# Maven 环境变量配置
export MAVEN_HOME=$INSTALL_DIR
export M2_HOME=$INSTALL_DIR

# 确保 PATH 中不会重复添加 Maven 路径
if [[ ":\$PATH:" != *":\$MAVEN_HOME/bin:"* ]]; then
    export PATH=\$PATH:\$MAVEN_HOME/bin
fi
EOF

    if [ $? -eq 0 ]; then
        print_success "Maven 环境变量已设置"
        # 刷新当前会话的环境变量
        source "$ENV_FILE"
        print_success "环境变量已刷新"
    else
        print_error "环境变量配置失败"
        exit 1
    fi
}

# 7. 创建用户和权限
createMavenUser(){
    print_section "配置用户和权限"
    
    # 7.1 创建用户组
    print_step "创建用户组..."
    if ! getent group "$MAVEN_GROUP" > /dev/null; then
        groupadd "$MAVEN_GROUP"
        print_success "已创建用户组: $MAVEN_GROUP"
    else
        print_info "用户组已存在: $MAVEN_GROUP"
    fi

    # 7.2 创建用户
    print_step "创建用户..."
    if ! id "$MAVEN_USER" > /dev/null 2>&1; then
        useradd -r -g "$MAVEN_GROUP" -s /usr/sbin/nologin "$MAVEN_USER"
        print_success "已创建用户: $MAVEN_USER"
    else
        print_info "用户已存在: $MAVEN_USER"
    fi

    # 7.3 更新权限
    print_step "更新目录权限..."
    if [ -d "$INSTALL_DIR" ]; then
        chown -R "$MAVEN_USER:$MAVEN_GROUP" "$INSTALL_DIR"
        print_success "已更新安装目录权限: $INSTALL_DIR"
    else
        print_warning "安装目录不存在: $INSTALL_DIR"
    fi

    if [ -d "$LOCAL_REPO" ]; then
        chown -R "$MAVEN_USER:$MAVEN_GROUP" "$LOCAL_REPO"
        print_success "已更新仓库目录权限: $LOCAL_REPO"
    else
        print_warning "本地仓库目录不存在: $LOCAL_REPO"
    fi
}

# 8. 验证安装
validateInstallResult(){
    print_section "验证安装结果"
    
    print_step "检查 Maven 版本..."
    EXPECTED_VERSION="3.8.7"
    if ! INSTALLED_VERSION=$(mvn -v | grep 'Apache Maven' | awk '{print $3}'); then
        print_error "无法获取 Maven 版本信息"
        exit 1
    fi

    if [ "$INSTALLED_VERSION" == "$EXPECTED_VERSION" ]; then
        print_success "Maven 安装成功"
        print_info "版本信息: Apache Maven $INSTALLED_VERSION"
    else
        print_error "版本不匹配"
        print_info "期望版本: $EXPECTED_VERSION"
        print_info "实际版本: $INSTALLED_VERSION"
        exit 1
    fi
}

# 9. 结束进程
stopProcess(){
    echo "-----------------------------Maven 安装成功 --------------------------------------"
}

# 主函数
main() {
    print_header
    select_operation
}

# 调用主函数
main
