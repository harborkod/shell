#!/bin/bash

# Jenkins 版本和安装目录
JENKINS_VERSION="2.426"
JENKINS_URL="https://mirrors.huaweicloud.com/jenkins/war/$JENKINS_VERSION/jenkins.war"
INSTALL_DIR="/usr/local/jenkins"
LOG_DIR="$INSTALL_DIR/log"
DATA_DIR="$INSTALL_DIR/data"
DOWNLOAD_DIR="/opt"
JENKINS_PORT=8080
LOG_FILE="$LOG_DIR/jenkins.log"
JENKINS_USER="jenkins"
JENKINS_GROUP="jenkins"
MAX_WAIT_TIME=60
CHECK_INTERVAL=1

# 检查是否有 root 权限
check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo "请以 root 权限运行此脚本"
        exit 1
    fi
}

# 检查 JDK 版本是否满足要求
check_jdk() {
    echo "检查 JDK 版本..."
    if ! java -version 2>&1 | grep -q "17"; then
        echo "错误：未检测到 JDK 17 或更高版本。请先安装 JDK 17 后再运行此脚本。"
        exit 1
    else
        echo "JDK 17 已安装，版本信息："
        java -version
    fi
    JAVA_PATH=$(command -v java)
    JAVA_HOME=$(dirname $(dirname $JAVA_PATH))
}

# 检查并安装字体
check_fonts() {
    echo "检查系统字体..."
    if ! fc-list | grep -q "DejaVu"; then
        echo "未检测到基本字体，正在安装必要的字体包..."
        if command -v yum >/dev/null 2>&1; then
            yum install -y fontconfig dejavu-sans-fonts
        elif command -v apt-get >/dev/null 2>&1; then
            apt-get update
            apt-get install -y fontconfig fonts-dejavu-core
        else
            echo "错误：无法自动安装字体包，请手动安装基本字体后再运行此脚本。"
            exit 1
        fi
        echo "字体包安装完成。"
    else
        echo "基本字体已存在，跳过安装。"
    fi
}

# 创建 Jenkins 系统用户和组
create_jenkins_user() {
    echo "检查是否存在 Jenkins 用户和组..."
    if ! id -u "$JENKINS_USER" >/dev/null 2>&1; then
        echo "创建 Jenkins 用户和组..."
        groupadd "$JENKINS_GROUP"
        useradd -r -g "$JENKINS_GROUP" -s /sbin/nologin "$JENKINS_USER"
        echo "用户 $JENKINS_USER 和组 $JENKINS_GROUP 创建成功"
    else
        echo "用户 $JENKINS_USER 已存在，跳过创建。"
    fi
}

# 检查并停止正在运行的 Jenkins 进程
stop_jenkins_process() {
    echo "检查是否有正在运行的 Jenkins 进程..."
    JENKINS_PID=$(pgrep -f "jenkins.war")
    if [ -n "$JENKINS_PID" ]; then
        echo "检测到正在运行的 Jenkins 进程 (PID: $JENKINS_PID)，正在终止..."
        kill -9 "$JENKINS_PID"
        echo "已终止运行的 Jenkins 进程"
    fi
}

# 清理历史数据
cleanup_old_data() {
    echo "清理 Jenkins 历史数据..."
    if [ -d "$INSTALL_DIR" ]; then
        rm -rf "$INSTALL_DIR"
        echo "已删除 Jenkins 安装目录 $INSTALL_DIR"
    fi
}

# 创建所需目录
create_directories() {
    echo "创建 Jenkins 目录结构..."
    mkdir -p "$INSTALL_DIR" "$LOG_DIR" "$DATA_DIR" "$DOWNLOAD_DIR"
    chown -R "$JENKINS_USER":"$JENKINS_GROUP" "$INSTALL_DIR" "$LOG_DIR" "$DATA_DIR"
    chmod -R 755 "$INSTALL_DIR" "$LOG_DIR" "$DATA_DIR"
}

# 下载 Jenkins WAR 文件
download_jenkins() {
    echo "下载 Jenkins WAR 文件..."
    cd "$DOWNLOAD_DIR"
    if [ ! -f "jenkins.war" ]; then
        wget -O jenkins.war "$JENKINS_URL"
    else
        echo "Jenkins WAR 文件已存在，跳过下载"
    fi
    mv jenkins.war "$INSTALL_DIR"
}

# 配置环境变量
configure_environment() {
    echo "配置 Jenkins 和 Java 环境变量..."
    cat <<EOF > /etc/profile.d/jenkins_env.sh
export JENKINS_HOME=$DATA_DIR
export JAVA_HOME=$JAVA_HOME
export PATH=\$PATH:$JAVA_HOME/bin:$INSTALL_DIR
EOF
    source /etc/profile.d/jenkins_env.sh
    echo "环境变量已配置完成"
}

# 创建启动命令文件并以指定用户启动 Jenkins
start_jenkins_as_user() {
    echo "创建启动命令文件..."
    cat <<EOF > "$INSTALL_DIR/startup_command.sh"
nohup $JAVA_HOME/bin/java -Xms256m -Xmx512m -DJENKINS_HOME=$DATA_DIR -jar $INSTALL_DIR/jenkins.war --httpPort=$JENKINS_PORT --webroot=$DATA_DIR >> $LOG_FILE 2>&1 &
EOF
    chmod +x "$INSTALL_DIR/startup_command.sh"
    
    echo "以 $JENKINS_USER 用户启动 Jenkins..."
    sudo -u "$JENKINS_USER" sh "$INSTALL_DIR/startup_command.sh"
}

# 检查日志内容确认启动
monitor_startup_log() {
    echo "监控 Jenkins 启动日志，确认启动状态..."
    TIME_PASSED=0

    while [[ $TIME_PASSED -lt $MAX_WAIT_TIME ]]; do
        if grep -q "Please use the following password to proceed to installation:" "$LOG_FILE"; then
            echo "Jenkins 安装成功并正在运行！"
            echo "访问地址: http://<server_ip>:$JENKINS_PORT"
            return
        fi
        sleep $CHECK_INTERVAL
        TIME_PASSED=$((TIME_PASSED + CHECK_INTERVAL))
    done

    echo "Jenkins 启动失败，请检查日志文件：$LOG_FILE"
    exit 1
}

# 打印初始管理员密码路径
display_initial_password() {
    echo "初始管理员密码文件路径：$DATA_DIR/secrets/initialAdminPassword"
    echo "请使用以下命令查看初始管理员密码："
    echo "cat $DATA_DIR/secrets/initialAdminPassword"
}

# 主程序执行流程
main() {
    check_root
    check_jdk
    check_fonts
    create_jenkins_user
    stop_jenkins_process
    cleanup_old_data
    create_directories
    download_jenkins
    configure_environment
    start_jenkins_as_user
    monitor_startup_log
    display_initial_password
}

main
