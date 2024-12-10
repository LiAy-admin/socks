#!/bin/bash

# 设置颜色输出
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 打印带颜色的信息函数
print_message() {
    echo -e "${GREEN}[INFO] $1${NC}"
}

print_error() {
    echo -e "${RED}[ERROR] $1${NC}"
}

# 检查并安装依赖
check_dependencies() {
    print_message "检查依赖..."
    local dependencies=(curl wget iputils-ping)
    local missing_deps=()

    for dep in "${dependencies[@]}"; do
        if ! command -v "${dep%% *}" >/dev/null 2>&1; then
            missing_deps+=("$dep")
        fi
    done

    if [ ${#missing_deps[@]} -ne 0 ]; then
        print_message "安装缺失的依赖: ${missing_deps[*]}"
        apt-get update
        apt-get install -y "${missing_deps[@]}"
        if [ $? -ne 0 ]; then
            print_error "依赖安装失败"
            exit 1
        fi
    fi
}

# 测试网速函数
test_speed() {
    echo -e "${BLUE}正在测试下载速度...${NC}"
    
    # 定义测试文件数组（选择不同大小的文件以测试不同情况）
    declare -A test_files=(
        ["GitHub Release"]="https://github.com/prometheus/prometheus/releases/download/v2.45.0/sha256sums.txt"
        ["GitLab Release"]="https://gitlab.com/gitlab-org/gitlab-runner/-/raw/main/README.md"
        ["Docker Image"]="https://raw.githubusercontent.com/docker/docker-ce/master/components/engine/LICENSE"
        ["Ubuntu Package"]="http://archive.ubuntu.com/ubuntu/pool/main/h/hostname/hostname_3.23.tar.gz"
        ["Python Package"]="https://files.pythonhosted.org/packages/source/p/pip/pip-23.2.1.tar.gz"
        ["Node Package"]="https://registry.npmjs.org/express/-/express-4.18.2.tgz"
        ["Maven Package"]="https://repo1.maven.org/maven2/org/springframework/spring-core/5.3.29/spring-core-5.3.29.pom"
        ["VS Code Extension"]="https://marketplace.visualstudio.com/_apis/public/gallery/publishers/ms-python/vsextensions/python/latest/vspackage"
        ["Alpine Package"]="https://dl-cdn.alpinelinux.org/alpine/latest-stable/main/x86_64/APKINDEX.tar.gz"
        ["Debian Package"]="http://ftp.debian.org/debian/pool/main/b/bash/bash_5.2.15-2+b2_amd64.deb"
    )
    
    # 测试所有站点的下载速度
    echo -e "\n${BLUE}测试多站点下载速度：${NC}"
    for site_name in "${!test_files[@]}"; do
        url="${test_files[$site_name]}"
        printf "%-20s" "$site_name"
        
        # 使用 wget 测试下载速度
        result=$(wget -O /dev/null "$url" 2>&1 | grep -i "saved")
        if [ $? -eq 0 ]; then
            speed=$(echo "$result" | awk '{print $3" "$4}')
            echo -e "${GREEN}$speed${NC}"
        else
            echo -e "${RED}下载失败${NC}"
        fi
    done
    
    echo -e "\n${BLUE}提示：${NC}"
    echo "1. 速度单位说明："
    echo "   - MB/s: 兆字节每秒"
    echo "   - KB/s: 千字节每秒"
    echo "2. 不同站点的速度可能会有差异，这是正常现象"
    echo "3. 建议选择最快的站点作为主要下载源"
}

# 检查代理状态
check_proxy_status() {
    if [ -n "$ALL_PROXY" ]; then
        echo -e "${GREEN}代理状态: 已启用${NC}"
        echo -e "当前代理: $ALL_PROXY"
    else
        echo -e "${RED}代理状态: 未启用${NC}"
    fi
}

# 卸载代理配置
uninstall_proxy() {
    echo -e "${RED}警告: 此操作将删除所有代理配置！${NC}"
    echo -n "确定要继续吗？[y/N] "
    read confirm
    if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
        # 删除环境变量配置
        sed -i '/http_proxy/d' /etc/environment
        sed -i '/https_proxy/d' /etc/environment
        sed -i '/ALL_PROXY/d' /etc/environment
        
        # 删除APT代理配置
        rm -f /etc/apt/apt.conf.d/proxy.conf
        
        # 删除bash别名和函数
        sed -i '/# 代理设置/,/^}/d' ~/.bashrc
        
        # 禁用当前代理
        unset ALL_PROXY
        unset http_proxy
        unset https_proxy
        
        echo -e "${GREEN}代理配置已完全删除${NC}"
        echo "请执行 'source ~/.bashrc' 或重新登录终端以使更改生效"
        exit 0
    else
        echo "取消卸载"
        return 1
    fi
}

# 加载配置文件
load_config() {
    if [ -f /etc/socks/config.conf ]; then
        source /etc/socks/config.conf
    else
        echo "未找到配置文件，将使用默认配置"
        PROXY_HOST="127.0.0.1"
        PROXY_PORT="1080"
        PROXY_PROTOCOL="http"
    fi
}

# 保存配置文件
save_config() {
    mkdir -p /etc/socks
    cat > /etc/socks/config.conf << EOF
# Socks代理配置文件
# 修改以下配置项来设置您的代理服务器

# 代理服务器地址（必填）
PROXY_HOST="$PROXY_HOST"

# 代理服务器端口（必填）
PROXY_PORT="$PROXY_PORT"

# 代理协议（可选，默认为http）
PROXY_PROTOCOL="$PROXY_PROTOCOL"

# 代理认证信息（可选）
#PROXY_USER=""
#PROXY_PASS=""
EOF
}

# 配置代理
config_proxy() {
    echo -e "${BLUE}代理配置${NC}"
    echo "当前配置："
    echo "1. 代理服务器：$PROXY_HOST"
    echo "2. 端口：$PROXY_PORT"
    echo "3. 协议：$PROXY_PROTOCOL"
    echo "4. 认证设置"
    echo "0. 返回主菜单"
    echo -n "请选择要修改的项目 [0-4]: "
    read choice

    case $choice in
        1)
            echo -n "请输入代理服务器地址: "
            read new_host
            if [ -n "$new_host" ]; then
                PROXY_HOST="$new_host"
                save_config
                echo -e "${GREEN}代理服务器地址已更新${NC}"
            fi
            ;;
        2)
            echo -n "请输入代理服务器端口: "
            read new_port
            if [[ "$new_port" =~ ^[0-9]+$ ]] && [ "$new_port" -ge 1 ] && [ "$new_port" -le 65535 ]; then
                PROXY_PORT="$new_port"
                save_config
                echo -e "${GREEN}代理服务器端口已更新${NC}"
            else
                echo -e "${RED}无效的端口号${NC}"
            fi
            ;;
        3)
            echo -n "请输入代理协议 (http/https): "
            read new_protocol
            if [ "$new_protocol" = "http" ] || [ "$new_protocol" = "https" ]; then
                PROXY_PROTOCOL="$new_protocol"
                save_config
                echo -e "${GREEN}代理协议已更新${NC}"
            else
                echo -e "${RED}无效的协议${NC}"
            fi
            ;;
        4)
            config_proxy_auth
            ;;
        0)
            return
            ;;
        *)
            echo -e "${RED}无效的选择${NC}"
            ;;
    esac
}

# 配置代理认证
config_proxy_auth() {
    echo -e "${BLUE}代理认证配置${NC}"
    echo "1. 启用/禁用认证"
    echo "2. 设置用户名"
    echo "3. 设置密码"
    echo "0. 返回上级菜单"
    echo -n "请选择 [0-3]: "
    read choice

    case $choice in
        1)
            if [ "$PROXY_AUTH" = "true" ]; then
                PROXY_AUTH="false"
                echo -e "${GREEN}已禁用代理认证${NC}"
            else
                PROXY_AUTH="true"
                echo -e "${GREEN}已启用代理认证${NC}"
            fi
            save_config
            ;;
        2)
            echo -n "请输入代理用户名: "
            read new_user
            if [ -n "$new_user" ]; then
                PROXY_USER="$new_user"
                save_config
                echo -e "${GREEN}代理用户名已更新${NC}"
            fi
            ;;
        3)
            echo -n "请输入代理密码: "
            read -s new_pass
            echo
            if [ -n "$new_pass" ]; then
                PROXY_PASS="$new_pass"
                save_config
                echo -e "${GREEN}代理密码已更新${NC}"
            fi
            ;;
        0)
            return
            ;;
        *)
            echo -e "${RED}无效的选择${NC}"
            ;;
    esac
}

# 生成代理URL
get_proxy_url() {
    if [ "$PROXY_AUTH" = "true" ] && [ -n "$PROXY_USER" ] && [ -n "$PROXY_PASS" ]; then
        echo "${PROXY_PROTOCOL}://${PROXY_USER}:${PROXY_PASS}@${PROXY_HOST}:${PROXY_PORT}"
    else
        echo "${PROXY_PROTOCOL}://${PROXY_HOST}:${PROXY_PORT}"
    fi
}

# 修改代理命令以使用配置
proxy_on() {
    local proxy_url=$(get_proxy_url)
    export ALL_PROXY="$proxy_url"
    export http_proxy="$proxy_url"
    export https_proxy="$proxy_url"
    echo -e "${GREEN}代理已启动${NC}"
    
    # 将代理设置写入环境文件
    cat > /etc/environment << EOF
http_proxy=$proxy_url
https_proxy=$proxy_url
ALL_PROXY=$proxy_url
EOF
    
    # 配置 apt 代理
    cat > /etc/apt/apt.conf.d/proxy.conf << EOF
Acquire::http::Proxy "$proxy_url";
Acquire::https::Proxy "$proxy_url";
EOF
}

# 显示菜单
show_menu() {
    echo -e "${BLUE}===== Socks 代理管理 =====${NC}"
    echo "1. 启动代理"
    echo "2. 禁用代理"
    echo "3. 代理状态"
    echo "4. 测试代理"
    echo "5. 网速测试"
    echo "6. 配置代理"
    echo "7. 卸载代理"
    echo "0. 退出"
    echo -e "${BLUE}========================${NC}"
    echo -n "请选择操作 [0-7]: "
}

# 在主循环中添加配置选项处理
while true; do
    show_menu
    read choice
    case $choice in
        1)
            proxy_on
            ;;
        2)
            proxy_off
            ;;
        3)
            check_proxy_status
            ;;
        4)
            test_proxy
            ;;
        5)
            test_speed
            ;;
        6)
            config_proxy
            ;;
        7)
            uninstall_proxy
            if [ $? -eq 0 ]; then
                break
            fi
            ;;
        0)
            echo "再见！"
            exit 0
            ;;
        *)
            echo -e "${RED}无效的选择，请重试${NC}"
            ;;
    esac
    echo
done