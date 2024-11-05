#!/bin/bash

# 输出开始安装的提示信息
echo "-----------------------------开始 Java 安装--------------------------------------"
start_time=$(date +%s)

# 检查依赖
check_dependencies() {
    echo "-----------------------------检查依赖--------------------------------------"
    # 检查是否具有 sudo 权限
    if [ "$EUID" -ne 0 ] && ! command -v sudo >/dev/null 2>&1; then
        echo "错误：此脚本需要 root 权限或 sudo 命令，请以 root 用户运行或确保 sudo 已安装。"
        exit 1
    fi

    # 检查 tar、wget 和 unzip
    for cmd in tar wget unzip; do
        if ! command -v $cmd >/dev/null 2>&1; then
            echo "未检测到 $cmd 命令，正在安装 $cmd..."
            if command -v yum >/dev/null 2>&1; then
                sudo yum install -y $cmd
            elif command -v apt-get >/dev/null 2>&1; then
                sudo apt-get install -y $cmd
            else
                echo "错误：无法自动安装 $cmd，请手动安装后再运行此脚本。"
                exit 1
            fi
        else
            echo "$cmd 已安装"
        fi
    done
}

# 显示 Java 版本选择菜单
select_java_version() {
    echo -e "\e[31m***************一键安装 Java 任意版本******************\e[0m"
    echo "请选择要安装的 Java 版本："
    echo "1) jdk-8u202"
    echo "2) openjdk-11.0.2"
    echo "3) openjdk-17.0.2"
    read -p "请输入序号 (1-3): " choice

    case $choice in
        1)
            jdk_version="jdk-8u202"
            download_url="https://repo.huaweicloud.com/java/jdk/8u202-b08/jdk-8u202-linux-x64.tar.gz"
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
            echo "无效的选择，退出安装。"
            exit 1
            ;;
    esac
    echo "您选择了 $jdk_version"
}

# 清理旧的安装包、安装目录和 alternatives 条目
cleanup_previous_installation() {
    echo "-----------------------------清理历史数据--------------------------------------"
    # 下载目录
    download_dir="/opt"
    jdk_package="$download_dir/$(basename $download_url)"

    # 删除已有的安装包
    if [ -f "$jdk_package" ]; then
        echo "发现已有的安装包：$jdk_package，正在删除..."
        rm -f "$jdk_package"
    fi

    # 删除旧的安装目录
    install_dir="/usr/local/$jdk_version"
    if [ -d "$install_dir" ]; then
        echo "发现已有的安装目录：$install_dir，正在删除..."
        rm -rf "$install_dir"
    fi

    # 备份并删除旧的环境变量配置文件
    env_file="/etc/profile.d/java_${jdk_version}.sh"
    if [ -f "$env_file" ]; then
        echo "发现已有的环境变量配置文件：$env_file，正在备份并删除..."
        sudo mv "$env_file" "${env_file}.bak_$(date +%Y%m%d%H%M%S)"
    fi

    # 清理旧的 alternatives 条目
    cleanup_alternatives
}

# 清理 alternatives 条目
cleanup_alternatives() {
    echo "-----------------------------清理 alternatives 条目--------------------------------------"
    if command -v update-alternatives >/dev/null 2>&1; then
        ALTERNATIVES_CMD="update-alternatives"
    elif command -v alternatives >/dev/null 2>&1; then
        ALTERNATIVES_CMD="alternatives"
    else
        echo "警告：未找到 update-alternatives 或 alternatives 命令，无法清理 alternatives 条目。"
        return
    fi

    # 删除与当前安装目录相关的 alternatives 条目
    if [ -x "$install_dir/bin/java" ]; then
        echo "正在移除 alternatives 条目：$install_dir/bin/java"
        sudo $ALTERNATIVES_CMD --remove java "$install_dir/bin/java"
    fi

    if [ -x "$install_dir/bin/javac" ]; then
        echo "正在移除 alternatives 条目：$install_dir/bin/javac"
        sudo $ALTERNATIVES_CMD --remove javac "$install_dir/bin/javac"
    fi
}

# 下载 JDK 安装包
download_jdk_package() {
    echo "-----------------------------下载 JDK 安装包--------------------------------------"
    # 检查网络连接
    if ! ping -c 1 -W 3 $(echo $download_url | awk -F/ '{print $3}') >/dev/null 2>&1; then
        echo "错误：无法连接到下载服务器，请检查网络连接。"
        exit 1
    fi

    # 下载新的安装包（增加重试机制）
    echo "正在下载 $jdk_version 安装包..."
    for i in {1..3}; do
        if wget -P "$download_dir" "$download_url"; then
            echo "下载完成：$jdk_package"
            break
        else
            echo "下载失败，重试第 $i 次..."
            sleep 2
        fi
        if [ $i -eq 3 ]; then
            echo "错误：下载失败，请检查网络连接。"
            exit 1
        fi
    done
}

# 创建安装目录
prepare_installation_directory() {
    # 检查磁盘空间
    required_space=500000 # 约500MB
    available_space=$(df "$download_dir" | tail -1 | awk '{print $4}')
    if [ "$available_space" -lt "$required_space" ]; then
        echo "错误：磁盘空间不足，请确保有足够的空间。"
        exit 1
    fi

    # 创建安装目录
    if ! mkdir -p "$install_dir"; then
        echo "创建目录 $install_dir 失败，请检查权限。"
        exit 1
    fi
    echo "安装目录 $install_dir 已创建完成。"
}

# 解压 JDK 安装包
extract_jdk_package() {
    echo "-----------------------------解压 JDK 安装包--------------------------------------"
    case "$jdk_package" in
        *.tar.gz|*.tgz)
            if ! tar -xzf "$jdk_package" -C "$install_dir" --strip-components=1; then
                echo "错误：解压 $jdk_package 时出错。"
                exit 1
            fi
            ;;
        *.tar)
            if ! tar -xf "$jdk_package" -C "$install_dir" --strip-components=1; then
                echo "错误：解压 $jdk_package 时出错。"
                exit 1
            fi
            ;;
        *.zip)
            if ! unzip -q "$jdk_package" -d "$install_dir"; then
                echo "错误：解压 $jdk_package 时出错。"
                exit 1
            fi
            ;;
        *)
            echo "不支持的压缩包格式。"
            exit 1
            ;;
    esac

    echo "JDK 已解压到目录：$install_dir"

    # 检查解压后的目录是否存在
    if [ ! -d "$install_dir/bin" ]; then
        echo "错误：解压后未找到预期的目录结构。请检查安装包是否完整。"
        exit 1
    fi
}

# 配置环境变量
configure_environment_variables() {
    echo "-----------------------------配置环境变量--------------------------------------"
    # 创建新的环境变量配置文件
    env_file="/etc/profile.d/java_${jdk_version}.sh"
    cat <<EOF | sudo tee "$env_file" >/dev/null
# Java 环境变量 - $jdk_version
export JAVA_HOME=$install_dir
export PATH=\$PATH:\${JAVA_HOME}/bin
EOF

    if [ $? -ne 0 ]; then
        echo "错误：写入环境变量配置文件失败。"
        exit 1
    fi

    # 使环境变量生效
    source "$env_file"
    echo "环境变量已配置，配置文件：$env_file"
    echo "请重新登录终端或手动运行 'source $env_file' 使环境变量生效。"
}

# 设置默认的 Java 版本
set_default_java() {
    echo "-----------------------------设置默认的 Java 版本--------------------------------------"

    # 检查是否存在 update-alternatives 或 alternatives 命令
    if command -v update-alternatives >/dev/null 2>&1; then
        ALTERNATIVES_CMD="update-alternatives"
    elif command -v alternatives >/dev/null 2>&1; then
        ALTERNATIVES_CMD="alternatives"
    else
        echo "警告：未找到 update-alternatives 或 alternatives 命令，无法设置默认 Java 版本。"
        return
    fi

    # 检查 JAVA_HOME/bin/java 是否存在
    if [ ! -x "$install_dir/bin/java" ]; then
        echo "错误：未找到 $install_dir/bin/java，可执行文件不存在。"
        exit 1
    fi

    # 注册新的 Java 版本
    sudo $ALTERNATIVES_CMD --install /usr/bin/java java "$install_dir/bin/java" 100
    sudo $ALTERNATIVES_CMD --install /usr/bin/javac javac "$install_dir/bin/javac" 100

    # 检查命令是否执行成功
    if [ $? -ne 0 ]; then
        echo "错误：注册 Java alternatives 失败。"
        exit 1
    fi

    # 将此版本设置为默认
    sudo $ALTERNATIVES_CMD --set java "$install_dir/bin/java"
    sudo $ALTERNATIVES_CMD --set javac "$install_dir/bin/javac"
    echo "已将 $jdk_version 设置为默认的 Java 版本。"
}

# 检查 Java 版本
verify_installation() {
    echo "-----------------------------检查 Java 版本--------------------------------------"
    if command -v java >/dev/null 2>&1; then
        echo "Java 已安装，版本信息："
        java -version
    else
        echo "错误：Java 安装失败，请重新登录终端或手动运行 'source /etc/profile.d/java_${jdk_version}.sh'，然后重试。"
        exit 1
    fi
}

# 完成安装
finish_installation() {
    end_time=$(date +%s)
    execution_time=$((end_time - start_time))
    echo "-----------------------------恭喜！Java 安装成功--------------------------------------"
    echo "脚本执行时间：${execution_time} 秒"
    echo "请重新登录终端或手动运行 'source /etc/profile.d/java_${jdk_version}.sh' 使环境变量生效。"
}

# 主程序
main() {
    check_dependencies
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
