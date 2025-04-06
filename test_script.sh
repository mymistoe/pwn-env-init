#!/bin/bash

# 支持的Linux发行版
DISTROS=(
    # Ubuntu系列
    # "ubuntu:18.04"  # 已测试
    # "ubuntu:20.04"  # 已测试
    # "ubuntu:22.04"  # 已测试
    # "ubuntu:23.10"  # 已测试
    "ubuntu:24.04"
    
    # Debian系列
    "debian:9"
    "debian:10"
    "debian:11"
    "debian:12"
    
    # Kali Linux
    "kalilinux/kali-rolling:latest"
    
    # Arch Linux
    "archlinux:latest"
    
    # Fedora
    "fedora:38"
    "fedora:39"
    
    # CentOS
    "centos:7"
    "centos:8"
    
    # Rocky Linux
    "rockylinux:8"
    "rockylinux:9"
    
    # AlmaLinux
    "almalinux:8"
    "almalinux:9"
    
    # OpenSUSE
    "opensuse/leap:15.5"
    "opensuse/tumbleweed:latest"
)

# 错误处理函数
handle_error() {
    local distro=$1
    local step=$2
    local error=$3
    echo -e "\n${RED}错误: $distro 在 $step 步骤失败${NC}"
    echo -e "${YELLOW}错误信息:${NC}"
    echo "$error"
    echo -e "\n${RED}测试终止${NC}"
    exit 1
}

# 测试函数
test_distro() {
    local distro=$1
    echo -e "\n${BLUE}开始测试 $distro...${NC}"
    
    # 根据发行版选择不同的包管理器
    local pkg_manager=""
    if [[ $distro == *"ubuntu"* ]] || [[ $distro == *"debian"* ]] || [[ $distro == *"kali"* ]]; then
        pkg_manager="apt-get"
    elif [[ $distro == *"fedora"* ]] || [[ $distro == *"centos"* ]] || [[ $distro == *"rocky"* ]] || [[ $distro == *"alma"* ]]; then
        pkg_manager="dnf"
    elif [[ $distro == *"arch"* ]]; then
        pkg_manager="pacman"
    elif [[ $distro == *"opensuse"* ]]; then
        pkg_manager="zypper"
    fi
    
    # 创建并运行容器
    local output=$(docker run -it --rm --init \
        -e DEBIAN_FRONTEND=noninteractive \
        -e TZ=Asia/Shanghai \
        -v $(pwd):/pwn-env \
        -w /pwn-env \
        $distro \
        bash -c "
            # 设置时区
            ln -fs /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
            
            # 更新系统
            echo '${BLUE}正在更新系统...${NC}'
            if ! $pkg_manager update -y; then
                echo '系统更新失败'
                exit 1
            fi
            
            # 安装基本工具
            echo '${BLUE}正在安装基本工具...${NC}'
            if [[ $pkg_manager == \"apt-get\" ]]; then
                if ! $pkg_manager install -y sudo git curl wget vim build-essential python3 python3-pip python3-dev tzdata; then
                    echo '基本工具安装失败'
                    exit 1
                fi
            elif [[ $pkg_manager == \"dnf\" ]]; then
                if ! $pkg_manager install -y sudo git curl wget vim gcc gcc-c++ make python3 python3-pip python3-devel tzdata; then
                    echo '基本工具安装失败'
                    exit 1
                fi
            elif [[ $pkg_manager == \"pacman\" ]]; then
                if ! $pkg_manager -Syu --noconfirm sudo git curl wget vim base-devel python python-pip tzdata; then
                    echo '基本工具安装失败'
                    exit 1
                fi
            elif [[ $pkg_manager == \"zypper\" ]]; then
                if ! $pkg_manager install -y sudo git curl wget vim gcc gcc-c++ make python3 python3-pip python3-devel timezone; then
                    echo '基本工具安装失败'
                    exit 1
                fi
            fi
            
            # 安装shell环境
            echo '${BLUE}正在安装shell环境...${NC}'
            if [[ $pkg_manager == \"apt-get\" ]]; then
                if ! $pkg_manager install -y zsh fish; then
                    echo 'shell环境安装失败'
                    exit 1
                fi
            elif [[ $pkg_manager == \"dnf\" ]]; then
                if ! $pkg_manager install -y zsh fish; then
                    echo 'shell环境安装失败'
                    exit 1
                fi
            elif [[ $pkg_manager == \"pacman\" ]]; then
                if ! $pkg_manager -S --noconfirm zsh fish; then
                    echo 'shell环境安装失败'
                    exit 1
                fi
            elif [[ $pkg_manager == \"zypper\" ]]; then
                if ! $pkg_manager install -y zsh fish; then
                    echo 'shell环境安装失败'
                    exit 1
                fi
            fi
            
            # 配置Python环境
            echo '${BLUE}正在配置Python环境...${NC}'
            if ! pip3 install --upgrade pip; then
                echo 'pip升级失败'
                exit 1
            fi
            if ! pip3 install pwntools; then
                echo 'pwntools安装失败'
                exit 1
            fi
            
            # 配置shell环境
            echo '${BLUE}正在配置shell环境...${NC}'
            if command -v zsh &> /dev/null; then
                if ! sh -c \"\$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)\" \"\" --unattended; then
                    echo 'oh-my-zsh安装失败'
                    exit 1
                fi
            fi
            
            # 运行测试脚本
            echo '${BLUE}正在运行测试脚本...${NC}'
            chmod +x pwn_init.sh
            if ! ./pwn_init.sh; then
                echo '测试脚本运行失败'
                exit 1
            fi
        " 2>&1)
    
    local exit_code=$?
    if [ $exit_code -ne 0 ]; then
        handle_error "$distro" "测试过程" "$output"
    else
        echo -e "${GREEN}$distro 测试通过${NC}"
    fi
}

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 检查Docker是否安装
if ! command -v docker &> /dev/null; then
    echo -e "${RED}错误: 请先安装Docker${NC}"
    exit 1
fi

# 主循环
for distro in "${DISTROS[@]}"; do
    test_distro "$distro"
done

echo -e "\n${GREEN}所有测试完成${NC}" 