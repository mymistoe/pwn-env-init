#!/bin/bash

set -eux

# 全局变量定义
python_version=""
INSTALL_FAILED=false
TEMP_FILES=()
TEMP_DIRS=()
TOTAL_STEPS=15
CURRENT_STEP=0
SHELLS=("bash" "zsh" "fish")
INSTALLED_SHELLS=()

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 时间跟踪
START_TIME=$(date +%s)
STEP_TIMES=()

# 命令执行检查函数
check_command() {
    local cmd_status=$?
    if [ $cmd_status -ne 0 ]; then
        error_exit "命令执行失败: $1 (状态码: $cmd_status)"
    fi
}

# 错误处理函数
error_exit() {
    echo -e "${RED}错误: $1${NC}" >&2
    cleanup
    exit 1
}

# 依赖包检查函数
check_dependency() {
    if ! command -v $1 &> /dev/null; then
        error_exit "缺少必要依赖: $1"
    fi
}

# 清理函数
cleanup() {
    echo -e "${YELLOW}正在清理临时文件...${NC}"
    
    # 清理临时文件
    for file in "${TEMP_FILES[@]}"; do
        if [ -f "$file" ]; then
            rm -f "$file"
            echo -e "${GREEN}已删除临时文件: $file${NC}"
        fi
    done
    
    # 清理临时目录
    for dir in "${TEMP_DIRS[@]}"; do
        if [ -d "$dir" ]; then
            rm -rf "$dir"
            echo -e "${GREEN}已删除临时目录: $dir${NC}"
        fi
    done
    
    # 如果安装失败，尝试回滚已安装的包
    if [ "$INSTALL_FAILED" = true ]; then
        echo -e "${YELLOW}正在回滚已安装的包...${NC}"
        # 回滚Python包
        if [ "$python_version" = "2" ]; then
            pip uninstall -y pwntools more-itertools || true
        else
            pip3 uninstall -y pwntools || true
        fi
        # 回滚系统包
        sudo apt-get remove -y libc6-i386 ruby || true
        sudo gem uninstall one_gadget || true
    fi
}

# 设置清理陷阱
trap cleanup EXIT

# 安全目录切换函数
safe_cd() {
    local target_dir="$1"
    if ! cd "$target_dir"; then
        error_exit "无法切换到目录: $target_dir"
    fi
}

# 检测shell环境函数
check_shell_env() {
    echo -e "${YELLOW}正在检测shell环境...${NC}"
    
    # 获取当前shell
    local current_shell=$(basename "$SHELL")
    echo -e "${GREEN}当前使用的shell: $current_shell${NC}"
    
    # 检查是否安装了其他常用shell
    INSTALLED_SHELLS=()
    
    for shell in "${SHELLS[@]}"; do
        if command -v $shell &> /dev/null; then
            local version=$($shell --version 2>&1 | head -n 1)
            INSTALLED_SHELLS+=("$shell")
            echo -e "${GREEN}已安装: $shell${NC} - $version"
        else
            echo -e "${YELLOW}未安装: $shell${NC}"
        fi
    done
    
    # 检查shell配置文件
    case $current_shell in
        "bash")
            if [ -f ~/.bashrc ]; then
                echo -e "${GREEN}检测到bash配置文件: ~/.bashrc${NC}"
            else
                echo -e "${YELLOW}未检测到bash配置文件: ~/.bashrc${NC}"
            fi
            ;;
        "zsh")
            if [ -f ~/.zshrc ]; then
                echo -e "${GREEN}检测到zsh配置文件: ~/.zshrc${NC}"
            else
                echo -e "${YELLOW}未检测到zsh配置文件: ~/.zshrc${NC}"
            fi
            ;;
        "fish")
            if [ -d ~/.config/fish ]; then
                echo -e "${GREEN}检测到fish配置目录: ~/.config/fish${NC}"
            else
                echo -e "${YELLOW}未检测到fish配置目录: ~/.config/fish${NC}"
            fi
            ;;
        *)
            echo -e "${YELLOW}警告: 检测到不常见的shell: $current_shell${NC}"
            ;;
    esac
    
    # 询问用户是否要安装其他shell
    if [ ${#INSTALLED_SHELLS[@]} -lt ${#SHELLS[@]} ]; then
        echo -e "${YELLOW}是否要安装其他shell环境？(y/N)${NC}"
        read install_other_shells
        if [[ $install_other_shells == "y" || $install_other_shells == "Y" ]]; then
            for shell in "${SHELLS[@]}"; do
                if ! command -v $shell &> /dev/null; then
                    echo -e "${YELLOW}是否安装 $shell？(y/N)${NC}"
                    read install_shell
                    if [[ $install_shell == "y" || $install_shell == "Y" ]]; then
                        sudo apt-get install -y $shell
                        check_command "安装$shell失败"
                        echo -e "${GREEN}已安装: $shell${NC}"
                    fi
                fi
            done
        fi
    fi
    
    # 更新总步骤数
    update_total_steps
}

# 检测Python环境函数
check_python_env() {
    echo -e "${YELLOW}正在检测本地Python环境...${NC}"
    
    # 检测Python2
    if command -v python2 &> /dev/null; then
        local py2_version=$(python2 --version 2>&1)
        echo -e "${GREEN}检测到Python2环境: $py2_version${NC}"
    else
        echo -e "${YELLOW}未检测到Python2环境${NC}"
    fi
    
    # 检测Python3
    if command -v python3 &> /dev/null; then
        local py3_version=$(python3 --version 2>&1)
        echo -e "${GREEN}检测到Python3环境: $py3_version${NC}"
    else
        echo -e "${YELLOW}未检测到Python3环境${NC}"
    fi
    
    # 检测pip
    if command -v pip &> /dev/null; then
        local pip_version=$(pip --version 2>&1)
        echo -e "${GREEN}检测到pip: $pip_version${NC}"
    else
        echo -e "${YELLOW}未检测到pip${NC}"
    fi
    
    # 检测pip3
    if command -v pip3 &> /dev/null; then
        local pip3_version=$(pip3 --version 2>&1)
        echo -e "${GREEN}检测到pip3: $pip3_version${NC}"
    else
        echo -e "${YELLOW}未检测到pip3${NC}"
    fi
    
    echo -e "${YELLOW}请选择要配置的Python版本 (2/3):${NC}"
    read python_version
    
    if [[ $python_version != "2" && $python_version != "3" ]]; then
        error_exit "无效的选择，请输入2或3"
    fi
    
    # 检查选择的Python版本是否已安装
    if [ "$python_version" = "2" ] && ! command -v python2 &> /dev/null; then
        echo -e "${YELLOW}警告: 您选择了Python2，但系统中未检测到Python2环境${NC}"
        echo -e "${YELLOW}是否继续安装Python2环境？(y/N)${NC}"
        read confirm
        if [[ $confirm != "y" && $confirm != "Y" ]]; then
            error_exit "安装已取消"
        fi
    elif [ "$python_version" = "3" ] && ! command -v python3 &> /dev/null; then
        echo -e "${YELLOW}警告: 您选择了Python3，但系统中未检测到Python3环境${NC}"
        echo -e "${YELLOW}是否继续安装Python3环境？(y/N)${NC}"
        read confirm
        if [[ $confirm != "y" && $confirm != "Y" ]]; then
            error_exit "安装已取消"
        fi
    fi
    
    # 更新总步骤数
    update_total_steps
}

# 权限检查函数
check_permissions() {
    # 检查root权限
    if [ "$EUID" -ne 0 ]; then 
        echo -e "${RED}错误: 请使用sudo运行此脚本${NC}"
        exit 1
    fi
    
    # 检查用户主目录权限
    if [ ! -w "$HOME" ]; then
        echo -e "${RED}错误: 用户主目录没有写入权限${NC}"
        exit 1
    fi
    
    # 检查必要的系统目录权限
    local system_dirs=("/usr/local/bin" "/usr/bin" "/usr/lib" "/usr/include")
    for dir in "${system_dirs[@]}"; do
        if [ ! -w "$dir" ]; then
            echo -e "${YELLOW}警告: 目录 $dir 没有写入权限，某些功能可能受限${NC}"
        fi
    done
    
    # 检查Python包安装目录权限
    if [ "$python_version" = "2" ]; then
        local python_dir=$(python2 -c "import site; print(site.getsitepackages()[0])" 2>/dev/null || true)
    else
        local python_dir=$(python3 -c "import site; print(site.getsitepackages()[0])" 2>/dev/null || true)
    fi
    
    if [ -n "$python_dir" ] && [ ! -w "$python_dir" ]; then
        echo -e "${YELLOW}警告: Python包目录 $python_dir 没有写入权限，可能需要使用sudo安装Python包${NC}"
    fi
    
    # 检查Ruby gem目录权限
    local gem_dir=$(gem environment gemdir 2>/dev/null || true)
    if [ -n "$gem_dir" ] && [ ! -w "$gem_dir" ]; then
        echo -e "${YELLOW}警告: Ruby gem目录 $gem_dir 没有写入权限，可能需要使用sudo安装gem包${NC}"
    fi
}

# 设置目录权限函数
set_directory_permissions() {
    local dirs=("$HOME/peda" "$HOME/pwndbg" "$HOME/libc-database")
    
    for dir in "${dirs[@]}"; do
        if [ -d "$dir" ]; then
            chmod -R 755 "$dir"
            echo -e "${GREEN}已设置目录权限: $dir${NC}"
        fi
    done
}

# 必要工具检查函数
check_required_tools() {
    local tools=("curl" "wget" "make" "gcc" "g++" "python" "python3" "pip" "pip3" "ruby" "gem")
    local missing_tools=()
    
    echo -e "${YELLOW}检查必要工具...${NC}"
    
    for tool in "${tools[@]}"; do
        if ! command -v $tool &> /dev/null; then
            missing_tools+=("$tool")
        else
            local version=$($tool --version 2>&1 | head -n 1)
            echo -e "${GREEN}已安装: $tool${NC} - $version"
        fi
    done
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        echo -e "${YELLOW}以下工具未安装，将在安装过程中自动安装:${NC}"
        for tool in "${missing_tools[@]}"; do
            echo -e "${YELLOW}- $tool${NC}"
        done
    fi
}

# 进度显示函数
show_progress() {
    local current=$1
    local total=$2
    local message=$3
    local percent=$((current * 100 / total))
    local bar_length=50
    local filled=$((percent * bar_length / 100))
    local bar=$(printf "%${filled}s" | tr " " "=")
    local empty=$(printf "%$((bar_length - filled))s" | tr " " " ")
    
    # 计算预计剩余时间
    local current_time=$(date +%s)
    local elapsed=$((current_time - START_TIME))
    local remaining=""
    
    # 避免除零错误
    if [ $current -gt 0 ]; then
        local avg_time=$((elapsed / current))
        local remaining_time=$((avg_time * (total - current)))
        local remaining_min=$((remaining_time / 60))
        local remaining_sec=$((remaining_time % 60))
        remaining="(预计剩余: ${remaining_min}:${remaining_sec})"
    else
        remaining="(正在初始化...)"
    fi
    
    # 使用颜色输出
    printf "\r${BLUE}[%-${bar_length}s]${NC} ${GREEN}%3d%%${NC} ${YELLOW}%s${NC} ${RED}%s${NC}" \
        "$bar$empty" "$percent" "$message" "$remaining"
}

# 更新进度函数
update_progress() {
    local step_start=$(date +%s)
    ((CURRENT_STEP++))
    show_progress "$CURRENT_STEP" "$TOTAL_STEPS" "$1"
    echo ""
    local step_end=$(date +%s)
    STEP_TIMES+=($((step_end - step_start)))
}

# 动态更新总步骤数
update_total_steps() {
    local additional_steps=0
    
    # 检查是否需要安装其他shell
    if [ ${#INSTALLED_SHELLS[@]} -lt ${#SHELLS[@]} ]; then
        for shell in "${SHELLS[@]}"; do
            if ! command -v $shell &> /dev/null; then
                ((additional_steps++))
            fi
        done
    fi
    
    # 检查是否需要安装Python环境
    if [ "$python_version" = "2" ] && ! command -v python2 &> /dev/null; then
        ((additional_steps++))
    elif [ "$python_version" = "3" ] && ! command -v python3 &> /dev/null; then
        ((additional_steps++))
    fi
    
    # 更新总步骤数
    TOTAL_STEPS=$((15 + additional_steps))
}

# 主程序开始
echo -e "${BLUE}Author : giantbranch ${NC}"
echo ""
echo -e "${BLUE}Github : https://github.com/giantbranch/pwn-env-init${NC}"
echo ""

# 初始化进度显示
show_progress 0 1 "正在初始化..."
echo ""

# 检查shell环境
check_shell_env
update_progress "Shell环境检测完成"

# 检查Python环境
check_python_env
update_progress "Python环境检测完成"

# 检查权限
check_permissions
update_progress "权限检查完成"

# 检查必要工具
check_required_tools
update_progress "必要工具检查完成"

# 检查必要依赖
echo -e "${YELLOW}检查系统依赖...${NC}"
check_dependency "apt-get"
check_dependency "git"
check_dependency "gdb"
update_progress "系统依赖检查完成"

# 创建临时目录
TEMP_DIR=$(mktemp -d)
TEMP_DIRS+=("$TEMP_DIR")
cd "$TEMP_DIR"

# 配置清华源
echo -e "${YELLOW}正在配置清华源...${NC}"

# 备份原有源
echo -e "${YELLOW}正在备份原有源文件到 /etc/apt/sources.list.bak${NC}"
echo -e "${YELLOW}如果需要恢复原有源，请执行: sudo cp /etc/apt/sources.list.bak /etc/apt/sources.list${NC}"
sudo cp /etc/apt/sources.list /etc/apt/sources.list.bak
check_command "备份原有源失败"

# 配置apt清华源
sudo tee /etc/apt/sources.list << EOF
# 默认注释了源码镜像以提高 apt update 速度，如有需要可自行取消注释
deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ jammy main restricted universe multiverse
# deb-src https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ jammy main restricted universe multiverse
deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ jammy-updates main restricted universe multiverse
# deb-src https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ jammy-updates main restricted universe multiverse
deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ jammy-backports main restricted universe multiverse
# deb-src https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ jammy-backports main restricted universe multiverse
deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ jammy-security main restricted universe multiverse
# deb-src https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ jammy-security main restricted universe multiverse
EOF
check_command "配置apt清华源失败"

# 配置pip清华源
if [ ! -d ~/.pip ]; then
  mkdir ~/.pip
fi
echo -e "[global]\nindex-url = https://pypi.tuna.tsinghua.edu.cn/simple/\n[install]\ntrusted-host = pypi.tuna.tsinghua.edu.cn" >  ~/.pip/pip.conf
check_command "配置pip清华源失败"

update_progress "配置清华源完成"

# support 32 bit
dpkg --add-architecture i386
check_command "添加32位架构支持失败"

sudo apt-get update
check_command "更新软件源失败"

sudo apt-get -y install libc6-i386
check_command "安装libc6-i386失败"

sudo apt-get -y install git gdb
check_command "安装git和gdb失败"
update_progress "安装系统依赖完成"

# install pwndbg
echo -e "${YELLOW}正在安装pwndbg...${NC}"
git clone https://github.com/pwndbg/pwndbg
check_command "克隆pwndbg失败"
safe_cd pwndbg
./setup.sh
check_command "安装pwndbg失败"
safe_cd "$TEMP_DIR"  # 确保返回临时目录
update_progress "安装pwndbg完成"

# install peda
echo -e "${YELLOW}正在安装peda...${NC}"
git clone https://github.com/longld/peda.git ~/peda
check_command "克隆peda失败"
echo "source ~/peda/peda.py" >> ~/.gdbinit
check_command "配置peda失败"
update_progress "安装peda完成"

# download the libc source
echo -e "${YELLOW}正在下载libc源码...${NC}"
sudo apt-get source libc6-dev
check_command "下载libc源码失败"
update_progress "下载libc源码完成"

# 根据用户选择安装不同版本的Python环境
if [ "$python_version" = "2" ]; then
    echo -e "${YELLOW}正在安装Python2环境...${NC}"
    sudo apt-get -y install python python-pip
    check_command "安装Python2失败"
    pip install more-itertools==5.0.0
    check_command "安装more-itertools失败"
    pip install pwntools
    check_command "安装pwntools失败"
else
    echo -e "${YELLOW}正在安装Python3环境...${NC}"
    sudo apt-get -y install python3 python3-pip
    check_command "安装Python3失败"
    pip3 install pwntools
    check_command "安装pwntools失败"
fi
update_progress "安装Python环境完成"

# install one_gadget
echo -e "${YELLOW}正在安装one_gadget...${NC}"
sudo apt-get -y install ruby
check_command "安装ruby失败"
sudo gem install one_gadget
check_command "安装one_gadget失败"
update_progress "安装one_gadget完成"

# download libc-database
echo -e "${YELLOW}正在安装libc-database...${NC}"
git clone https://github.com/niklasb/libc-database.git ~/libc-database
check_command "克隆libc-database失败"
update_progress "安装libc-database完成"

echo -e "${YELLOW}Do you want to download libc-database now(Y/n)?${NC}"
read input
if [[ $input = "n" ]] || [[ $input = "N" ]]; then
    echo -e "${YELLOW}you can cd ~/libc-database and run ./get to download the libc at anytime you want${NC}"
else
    safe_cd ~/libc-database
    ./get
    check_command "下载libc-database失败"
    safe_cd "$TEMP_DIR"  # 确保返回临时目录
    update_progress "下载libc-database完成"
fi

# 设置目录权限
set_directory_permissions
update_progress "设置目录权限完成"

# 安装成功，清除安装失败标志
INSTALL_FAILED=false

echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}=============Good, Enjoy it.=============${NC}"
echo -e "${GREEN}=========================================${NC}"
