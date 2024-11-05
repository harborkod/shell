#! /usr/bash

# Jenkins 版本和安装目录
MAVEN_VERSION="3.8.7"
MAVEN_SOURCE_URL="https://harborkod.oss-rg-china-mainland.aliyuncs.com/arch/maven/apache-maven-3.8.7-bin.tar.gz"
DOWNLOAD_DIR="/opt"
INSTALL_DIR="/usr/local/apache-maven-3.8.7"
LOCAL_REPO="/repo"  
MAVEN_USER="maven"
MAVEN_GROUP="maven"

# 1. 提示
prompt(){
    echo "-----------------------------开始 Maven 安装--------------------------------------"
}

# 2. 进程校验（判断是否有maven进程）
validate_process(){
    echo "检查是否有正在运行的 maven 进程..."
    MAVEN_PID=$(pgrep -f "maven" | grep -v $$)  # 排除当前脚本进程

    if [ -n "$MAVEN_PID" ]; then
        echo "检测到正在运行的 maven 进程 (PID: $MAVEN_PID)，正在终止..."
        kill -9 "$MAVEN_PID"
        echo "已终止运行的 maven 进程"
    else
        echo "没有检测到正在运行的 maven 进程。"
    fi
}

# 3. 清理旧数据（源码包、安装目录、环境变量配置）
clearOldData(){
    # 3.1 清理源码包（/opt/apache-maven-3.8.7-bin.tar.gz）
    echo "清理 maven 源码包(tar.gz)..."
    if [ -f "$INSTALL_DIR/apache-maven-$MAVEN_VERSION-bin.tar.gz" ]; then
        rm -f "$INSTALL_DIR/apache-maven-$MAVEN_VERSION-bin.tar.gz"
        echo "已删除 maven 源码包(tar.gz) $INSTALL_DIR/apache-maven-$MAVEN_VERSION-bin.tar.gz"
    fi

    # 2.2 清理安装目录(/usr/local/apache-maven-3.8.7)
    echo "清理 maven 安装目录(/usr/local/)..."
    if [ -d "$INSTALL_DIR" ]; then
        rm -rf "$INSTALL_DIR"
        echo "已删除 maven 安装目录 $INSTALL_DIR"
    fi

    # 3.3 清理环境变量配置(/etc/profile.d/maven.sh)
    ENV_FILE="/etc/profile.d/maven.sh"
    if [ -f "$ENV_FILE" ]; then
        rm -f "$ENV_FILE"
        echo "已删除环境变量配置文件 $ENV_FILE"
    fi
}

# 4. 下载并解压源码包
downloadSourcePackage(){
    # 4.1 磁盘空间检测
    AVAILABLE_SPACE=$(df /usr/local | tail -1 | awk '{print $4}')
    if [ "$AVAILABLE_SPACE" -lt 5000000 ]; then
        echo "错误：磁盘空间不足，至少需要 5GB 可用空间。"
        exit 1
    fi

    # 4.2 下载源码
    echo "-----------------------------下载 maven 源码--------------------------------------"
    cd $DOWNLOAD_DIR
    if [ -f "apache-maven-$MAVEN_VERSION-bin.tar.gz" ]; then
        echo "maven 源码包已存在，跳过下载。"
    else
        wget -O apache-maven-$MAVEN_VERSION-bin.tar.gz $MAVEN_SOURCE_URL
        if [ $? -ne 0 ]; then
            echo "错误：下载 maven 源码包失败。"
            exit 1
        fi
    fi

    # 4.3 验证 SHA-512 校验码
    EXPECTED_CHECKSUM="21c2be0a180a326353e8f6d12289f74bc7cd53080305f05358936f3a1b6dd4d91203f4cc799e81761cf5c53c5bbe9dcc13bdb27ec8f57ecf21b2f9ceec3c8d27"  # 替换为实际校验码
    ACTUAL_CHECKSUM=$(sha512sum apache-maven-$MAVEN_VERSION-bin.tar.gz | awk '{ print $1 }')
    if [ "$EXPECTED_CHECKSUM" != "$ACTUAL_CHECKSUM" ]; then
        echo "错误：文件校验失败，下载的文件可能已损坏。"
        exit 1
    fi

    # 4.4 解压
    tar -zxvf apache-maven-$MAVEN_VERSION-bin.tar.gz -C /usr/local
}


# 5. 修改配置类（磁盘空间是否足够）
modifySettingFile(){
    # 5.1 磁盘空间检测 10G
    AVAILABLE_SPACE_ROOT=$(df / | tail -1 | awk '{print $4}')
    if [ "$AVAILABLE_SPACE_ROOT" -lt 10000000 ]; then
        echo "错误：磁盘空间不足，至少需要 10GB 可用空间。"
        exit 1
    fi

    # 5.2 设置本地仓库
    LOCAL_REPO="/repo"
    if [ ! -d "$LOCAL_REPO" ]; then
        mkdir -p "$LOCAL_REPO"
        echo "创建本地仓库目录: $LOCAL_REPO"
    fi

    # 5.3 备份原始配置文件
    SETTINGS_FILE="$INSTALL_DIR/conf/settings.xml"
    cp "$SETTINGS_FILE" "$SETTINGS_FILE.bak"
    echo "已备份原始配置文件到 $SETTINGS_FILE.bak"

    # 5.4 清空原配置文件内容
    > "$SETTINGS_FILE"

    # 5.5 写入新的基本结构和配置
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
    echo "已更新 Maven 配置文件。"
}

# 6. 设置环境变量（刷新环境变量）
addEnvPath(){
    # 6.1 设置 Maven 环境变量
    ENV_FILE="/etc/profile.d/maven.sh"
    
    # 创建环境变量配置文件（如果不存在）
    if [ ! -f "$ENV_FILE" ]; then
        touch "$ENV_FILE"
    fi

    # 检查环境变量是否已存在
    if grep -q "export MAVEN_HOME=" "$ENV_FILE" && grep -q "export M2_HOME=" "$ENV_FILE"; then
        echo "Maven 环境变量已存在，跳过设置。"
    else
        # 创建或清空环境变量配置文件
        echo "export MAVEN_HOME=$INSTALL_DIR" > "$ENV_FILE"
        echo "export M2_HOME=$INSTALL_DIR" >> "$ENV_FILE"
        echo "export PATH=\$PATH:\$MAVEN_HOME/bin" >> "$ENV_FILE"
        echo "已设置 Maven 和 M2 环境变量。"
    fi

    # 6.2 刷新环境变量
    source "$ENV_FILE"
    echo "已刷新环境变量。"
}

# 7. 创建用户组和用户（系统用户，不登录），更新权限
createMavenUser(){
    # 7.1 创建用户组
    MAVEN_GROUP="maven"
    if ! getent group "$MAVEN_GROUP" > /dev/null; then
        echo "创建用户组: $MAVEN_GROUP"
        groupadd "$MAVEN_GROUP"
    else
        echo "用户组 $MAVEN_GROUP 已存在，跳过创建。"
    fi

    # 7.2 创建用户
    MAVEN_USER="maven"
    if ! id "$MAVEN_USER" > /dev/null 2>&1; then
        echo "创建用户: $MAVEN_USER"
        useradd -r -g "$MAVEN_GROUP" -s /usr/sbin/nologin "$MAVEN_USER"
    else
        echo "用户 $MAVEN_USER 已存在，跳过创建。"
    fi

    # 7.3 更新权限
    # 确保 INSTALL_DIR 和 LOCAL_REPO 已经被正确设置
    if [ -d "$INSTALL_DIR" ]; then
        echo "更新权限: $INSTALL_DIR"
        chown -R "$MAVEN_USER:$MAVEN_GROUP" "$INSTALL_DIR"
    else
        echo "警告: 安装目录 $INSTALL_DIR 不存在，无法更新权限。"
    fi

    if [ -d "$LOCAL_REPO" ]; then
        echo "更新权限: $LOCAL_REPO"
        chown -R "$MAVEN_USER:$MAVEN_GROUP" "$LOCAL_REPO"
    else
        echo "警告: 本地仓库 $LOCAL_REPO 不存在，无法更新权限。"
    fi

    echo "权限已更新。"
}

# 8. 验证是否安装成功
validateInstallResult(){
    # 检查 Maven 版本是否符合预期
    EXPECTED_VERSION="3.8.7"  # 替换为你期望的版本号
    INSTALLED_VERSION=$(mvn -v | grep 'Apache Maven' | awk '{print $3}')

    if [ "$INSTALLED_VERSION" == "$EXPECTED_VERSION" ]; then
        echo "Maven 安装成功，版本信息：$INSTALLED_VERSION"
    else
        echo "错误：Maven 安装失败或版本不匹配。"
        echo "期望版本: $EXPECTED_VERSION, 实际版本: $INSTALLED_VERSION"
        exit 1
    fi
}

# 9. 结束进程
stopProcess(){
    echo "-----------------------------Maven 安装成功 --------------------------------------"
}

main(){
    prompt
    validate_process
    clearOldData
    downloadSourcePackage
    modifySettingFile
    addEnvPath
    createMavenUser
    validateInstallResult
    stopProcess
}

main