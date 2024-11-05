#! /usr/bash

# Jenkins 版本和安装目录
MAVEN_VERSION="3.8.7"
JENKINS_URL="https://harborkod.oss-rg-china-mainland.aliyuncs.com/arch/maven/apache-maven-$MAVEN_VERSION-bin.tar.gz"
DOWNLOAD_DIR="/opt"
INSTALL_DIR="/usr/local/maven"
MAVEN_USER="maven"
MAVEN_GROUP="maven"

# 1. 提示
prompt(){
    echo "-----------------------------开始 Maven 安装--------------------------------------"
}

# 2. 进程校验（判断是否有maven进程）
validate_process(){
    echo "检查是否有正在运行的 maven 进程..."
    MAVEN_PID=$(pgrep -f "maven")
    if [ -n "$MAVEN_PID" ]; then
        echo "检测到正在运行的 maven 进程 (PID: $MAVEN_PID)，正在终止..."
        kill -9 "$MAVEN_PID"
        echo "已终止运行的 maven 进程"
    fi
}

# 3. 清理旧数据
clearOldData(){
    # 2.1 清理 下载目录
    echo "清理 maven 历史数据..."
    if [ -d "$INSTALL_DIR" ]; then
        rm -rf "$INSTALL_DIR"
        echo "已删除 maven 安装目录 $INSTALL_DIR"
    fi

    # 2.1 清理 安装目录
    if [ -d "$INSTALL_DIR" ]; then
        rm -rf "$INSTALL_DIR"
        echo "已删除 maven 安装目录 $INSTALL_DIR"
    fi
}

# 4. 下载源码包
downloadSourcePackage(){
    
}

# 5. 解压并移动目录
extractAndMoveSourcePackage(){
    # 5.1 磁盘空间检测
    AVAILABLE_SPACE=$(df /usr/local | tail -1 | awk '{print $4}')
    if [ "$AVAILABLE_SPACE" -lt 5000000 ]; then
        echo "错误：磁盘空间不足，至少需要 5GB 可用空间。"
        exit 1
    fi


}

# 6. 修改配置类（磁盘空间是否足够）
modifySettingFile(){

}

# 7. 设置环境变量（刷新环境变量）
addEnvPath(){

}

# 8. 验证是否安装成功
validateInstallResult(){

}

# 9. 结束进程
stopProcess(){

}

main(){
    prompt
    validate_process
    clearOldData
    downloadSourcePackage
    extractAndMoveSourcePackage
    modifySettingFile
    addEnvPath
    validateInstallResult
    stopProcess
}

main