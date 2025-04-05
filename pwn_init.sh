#!/bin/bash

set -eux

# 错误处理函数
error_exit() {
    echo "错误: $1" >&2
    cleanup
    exit 1
}

# 命令执行检查函数
check_command() {
    if [ $? -ne 0 ]; then
        error_exit "命令执行失败: $1"
    fi
}

# 依赖包检查函数
check_dependency() {
    if ! command -v $1 &> /dev/null; then
        error_exit "缺少必要依赖: $1"
    fi
}

# 临时文件列表
TEMP_FILES=()
TEMP_DIRS=()

# 清理函数
cleanup() {
    echo "正在清理临时文件..."
    
    # 清理临时文件
    for file in "${TEMP_FILES[@]}"; do
        if [ -f "$file" ]; then
            rm -f "$file"
            echo "已删除临时文件: $file"
        fi
    done
    
    # 清理临时目录
    for dir in "${TEMP_DIRS[@]}"; do
        if [ -d "$dir" ]; then
            rm -rf "$dir"
            echo "已删除临时目录: $dir"
        fi
    done
    
    # 如果安装失败，尝试回滚已安装的包
    if [ "$INSTALL_FAILED" = true ]; then
        echo "正在回滚已安装的包..."
        # 回滚Python包
        if [ "$python_version" = "2" ]; then
            pip uninstall -y pwntools more-itertools
        else
            pip3 uninstall -y pwntools
        fi
        # 回滚系统包
        sudo apt-get remove -y libc6-i386 ruby
        sudo gem uninstall one_gadget
    fi
}

# 设置清理陷阱
trap cleanup EXIT

# 安装状态标志
INSTALL_FAILED=false

echo "Author : giantbranch "
echo ""
echo "Github : https://github.com/giantbranch/pwn-env-init"
echo ""

# 检查必要依赖
echo "检查系统依赖..."
check_dependency "apt-get"
check_dependency "git"
check_dependency "gdb"

# 询问用户选择Python版本
echo "请选择Python版本 (2/3):"
read python_version

if [[ $python_version != "2" && $python_version != "3" ]]; then
    error_exit "无效的选择，请输入2或3"
fi

# 创建临时目录
TEMP_DIR=$(mktemp -d)
TEMP_DIRS+=("$TEMP_DIR")
cd "$TEMP_DIR"

# change sourse to ustc
echo "I suggest you modify the /etc/apt/sources.list file to speed up the download."
# echo "Press Enter to continue~"
# read -t 5 test
#sudo  sed -i 's/archive.ubuntu.com/mirrors.ustc.edu.cn/g' /etc/apt/sources.list
# change sourse —— deb-src 
sudo sed -i 's/# deb-src/deb-src/' "/etc/apt/sources.list"
check_command "修改sources.list失败"

# change pip source
if [ ! -d ~/.pip ]; then
  mkdir ~/.pip
fi
echo -e "[global]\nindex-url = https://pypi.douban.com/simple/\n[install]\ntrusted-host = pypi.douban.com" >  ~/.pip/pip.conf
check_command "配置pip源失败"

# support 32 bit
dpkg --add-architecture i386
check_command "添加32位架构支持失败"

sudo apt-get update
check_command "更新软件源失败"

# sudo apt-get -y install lib32z1
sudo apt-get -y install libc6-i386
check_command "安装libc6-i386失败"

# maybe git？
sudo apt-get -y install git gdb
check_command "安装git和gdb失败"

# install pwndbg
echo "正在安装pwndbg..."
git clone https://github.com/pwndbg/pwndbg
check_command "克隆pwndbg失败"
cd pwndbg
./setup.sh
check_command "安装pwndbg失败"

# install peda
echo "正在安装peda..."
git clone https://github.com/longld/peda.git ~/peda
check_command "克隆peda失败"
echo "source ~/peda/peda.py" >> ~/.gdbinit
check_command "配置peda失败"

# download the libc source to current directory(you can use gdb with this example command: directory ~/glibc-2.24/malloc/)
echo "正在下载libc源码..."
sudo apt-get source libc6-dev
check_command "下载libc源码失败"

# 根据用户选择安装不同版本的Python环境
if [ "$python_version" = "2" ]; then
    echo "正在安装Python2环境..."
    sudo apt-get -y install python python-pip
    check_command "安装Python2失败"
    pip install more-itertools==5.0.0
    check_command "安装more-itertools失败"
    pip install pwntools
    check_command "安装pwntools失败"
else
    echo "正在安装Python3环境..."
    sudo apt-get -y install python3 python3-pip
    check_command "安装Python3失败"
    pip3 install pwntools
    check_command "安装pwntools失败"
fi

# install one_gadget
echo "正在安装one_gadget..."
sudo apt-get -y install ruby
check_command "安装ruby失败"
sudo gem install one_gadget
check_command "安装one_gadget失败"

# download 
echo "正在安装libc-database..."
git clone https://github.com/niklasb/libc-database.git ~/libc-database
check_command "克隆libc-database失败"

echo "Do you want to download libc-database now(Y/n)?"
read input
if [[ $input = "n" ]] || [[ $input = "N" ]]; then
	echo "you can cd ~/libc-database and run ./get to download the libc at anytime you want"
else
	cd ~/libc-database && ./get
    check_command "下载libc-database失败"
fi
echo "========================================="
echo "=============Good, Enjoy it.============="
echo "========================================="

# 安装成功，清除安装失败标志
INSTALL_FAILED=false
