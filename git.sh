#! /bin/bash

# 1.全局变量初始化
initGlobalVar(){
    CHECK_PATH="/"              # 检测路径
    REQUIRED_SPACE=5            # 所需磁盘空间（单位GB）
    DEPENDENCIES=("curl" "tar" "wget")  # 依赖项数组
    REQUIRED_USER="root"        # 权限校验的用户
    REQUIRED_PROCESS="git"      # 进程校验的进程
    DOWNLOAD_URL="https://harborkod.oss-rg-china-mainland.aliyuncs.com/arch/git/git-2.39.2.tar.gz"
    VERSIOIN="2.39.2"
}

# 检测磁盘可用空间,参数1：指定路径；参数2：磁盘空间大小（单位GB）
checkAvaliableDiskSpace(){
    local path=$1         # 获取第一个参数,指定路径
    local required_space=$2  # 获取第二个参数，磁盘空间大小（单位GB）

    # 参数校验
    if [[ -z "$path" || -z "$required_space" ]]; then
        echo "Error: Missing required arguments. Usage: checkAvaliableDiskSpace <path> <required_space_in_GB>"
        exit 1  
    fi

    # 获取指定路径的可用磁盘空间，以 GB 为单位
    local available_space=$(df -BG --output=avail "$path" | tail -n 1 | tr -d 'G')
    
    # 判断可用空间是否小于所需空间
    if (( available_space < required_space )); then
        echo "Error: Available disk space on $path is only ${available_space}GB, but ${required_space}GB is required."
        exit 1  # 如果空间不足，退出脚本
    else
        echo "Sufficient disk space on $path: ${available_space}GB available."
    fi
}

# 依赖项检测,数组参数（支持多个依赖项）
checkDependencies(){
    local dependencies=("$@")  # 获取所有参数作为数组
    local missing_dependencies=()  # 用于存放缺失的依赖项

    # 参数校验
    if [ ${#dependencies[@]} -eq 0 ]; then
        echo "No dependencies provided, skipping dependency check."
        return  # 如果没有提供依赖项，直接返回，不退出脚本
    fi

    for dependency in "${dependencies[@]}"; do
        if ! command -v "$dependency" &> /dev/null; then
            missing_dependencies+=("$dependency")  # 将缺失的依赖项添加到数组
        fi
    done

    # 输出缺失的依赖项
    if [ ${#missing_dependencies[@]} -ne 0 ]; then
        echo "Error: The following dependencies are not installed: ${missing_dependencies[*]}"
        exit 1  # 如果有缺失的依赖项，退出脚本
    else
        echo "All dependencies are installed."
    fi
}

# 权限校验,参数：root
checkPermission(){
    local user=$1  # 获取第一个参数

    # 检查当前用户是否为所需用户
    if [[ "$EUID" -ne 0 ]]; then
        echo "Error: This script must be run as root (current user: $user)."
        exit 1  # 如果当前用户不是 root，退出脚本
    else
        echo "Permission check passed: Running as root."
    fi
}

# 进程校验,参数：git
checkProcess(){
    local process_name=$1  # 获取第一个参数

    # 检查进程是否正在运行
    local pids=$(pgrep "$process_name")  # 获取进程的 PID

    if [ -n "$pids" ]; then
        echo "Error: The process '$process_name' is already running with PIDs: $pids."
        exit 1  # 如果进程正在运行，退出脚本
    fi
}

# 2.预检
preCheck(){
    # 2.1 磁盘空间检测
    checkAvaliableDiskSpace "$CHECK_PATH" "$REQUIRED_SPACE"

    # 2.2 依赖项检测
    checkDependencies "$DEPENDENCIES"

    # 2.3 root 权限检测
    checkPermission  "$REQUIRED_USER"

    # 2.4 进程校验
    checkProcess  "$REQUIRED_PROCESS"
}

# 3.安装包下载
downloadSourePackage(){
    
}

# 4.创建用户组和用户
createUserGroupAndUser(){

}

# 5.解压安装包
extractTarPackage(){

}

# 6.移动到安装目录
moveToInstallDir(){

}

# 7.执行安装编译
installOrCompile(){

}

# 8.配置环境变量
configureEnv(){

}

# 9.验证是否安装成功
afterCheck(){
    
}

main(){
    initGlobalVar
    preCheck
    downloadSourePackage
    createUserGroupAndUser
    extractTarPackage
    moveToInstallDir
    installOrCompile
    configureEnv
    afterCheck
}

main