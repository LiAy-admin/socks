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

# 显示菜单
show_menu() {
    echo -e "${BLUE}===== Socks 代理管理 =====${NC}"
    echo "1. 启动代理"
    echo "2. 禁用代理"
    echo "3. 代理状态"
    echo "4. 测试代理"
    echo "5. 网速测试"
    echo "6. 卸载代理"
    echo "0. 退出"
    echo -e "${BLUE}========================${NC}"
    echo -n "请选择操作 [0-6]: "
}

# 修改 socks 命令脚本
print_message "创建socks命令..."
cat > /usr/local/bin/socks << 'EOL'
#!/bin/bash

# 设置颜色输出
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 加载系统代理设置
load_proxy_settings() {
    if [ -f /etc/environment ]; then
        # 从 /etc/environment 加载代理设置
        while IFS='=' read -r key value; do
            if [[ $key == "http_proxy" ]]; then
                export http_proxy="$value"
            elif [[ $key == "https_proxy" ]]; then
                export https_proxy="$value"
            elif [[ $key == "ALL_PROXY" ]]; then
                export ALL_PROXY="$value"
            fi
        done < /etc/environment
    fi
}

# 显示菜单
show_menu() {
    echo -e "${BLUE}===== Socks 代理管理 =====${NC}"
    echo "1. 启动代理"
    echo "2. 禁用代理"
    echo "3. 代理状态"
    echo "4. 测试代理"
    echo "5. 网速测试"
    echo "6. 卸载代理"
    echo "0. 退出"
    echo -e "${BLUE}========================${NC}"
    echo -n "请选择操作 [0-6]: "
}

# 代理命令
proxy_on() {
    export ALL_PROXY=http://127.0.0:9093
    export http_proxy=http://127.0.0:9093
    export https_proxy=http://127.0.0:9093
    echo -e "${GREEN}代理已启动${NC}"
    
    # 将代理设置写入环境文件
    cat > /etc/environment << EOF
http_proxy=http://127.0.0.1:9093
https_proxy=http://127.0.0.1:9093
ALL_PROXY=http://127.0.0.1:9093
EOF
    
    # 配置 apt 代理
    cat > /etc/apt/apt.conf.d/proxy.conf << EOF
Acquire::http::Proxy "http://127.0.0:9093";
Acquire::https::Proxy "http://127.0.0:9093";
EOF
}

proxy_off() {
    unset ALL_PROXY
    unset http_proxy
    unset https_proxy
    echo -e "${RED}代理已禁用${NC}"
    
    # 清除环境文件中的代理设置
    : > /etc/environment
    
    # 清除 apt 代理设置
    rm -f /etc/apt/apt.conf.d/proxy.conf
}

# 检查代理状态
check_proxy_status() {
    if [ -n "$http_proxy" ] || [ -n "$https_proxy" ] || [ -n "$ALL_PROXY" ]; then
        echo -e "${GREEN}代理已启用${NC}"
        echo "http_proxy=$http_proxy"
        echo "https_proxy=$https_proxy"
        echo "ALL_PROXY=$ALL_PROXY"
    else
        echo -e "${RED}代理未启用${NC}"
    fi
}

# 测试代理
test_proxy() {
    echo -e "${BLUE}正在测试代理...${NC}"
    
    # 定义测试站点数组
    declare -A test_sites=(
        ["GitHub"]="https://github.com"
        ["GitLab"]="https://gitlab.com"
        ["Docker Hub"]="https://hub.docker.com"
        ["Python PyPI"]="https://pypi.org"
        ["NPM"]="https://registry.npmjs.org"
        ["Maven Central"]="https://repo.maven.apache.org"
        ["Ruby Gems"]="https://rubygems.org"
        ["Golang"]="https://golang.org"
        ["Rust Crates"]="https://crates.io"
        ["Stack Overflow"]="https://stackoverflow.com"
        ["Google"]="https://www.google.com"
        ["OpenAI"]="https://api.openai.com"
        ["Hugging Face"]="https://huggingface.co"
        ["Anaconda"]="https://anaconda.org"
        ["VS Code Marketplace"]="https://marketplace.visualstudio.com"
        ["JetBrains"]="https://www.jetbrains.com"
        ["Ubuntu Packages"]="https://packages.ubuntu.com"
        ["CPAN"]="https://www.cpan.org"
        ["Alpine Linux"]="https://alpinelinux.org"
        ["Debian Packages"]="https://www.debian.org/distrib/packages"
    )
    
    # 测试所有站点
    success_count=0
    total_sites=${#test_sites[@]}
    
    echo -e "\n${BLUE}1. 代码托管平台${NC}"
    for site in "GitHub" "GitLab"; do
        url="${test_sites[$site]}"
        printf "%-20s" "$site"
        if curl -s --connect-timeout 5 "$url" > /dev/null; then
            echo -e "${GREEN}✓ 连接成功${NC}"
            ((success_count++))
        else
            echo -e "${RED}✗ 连接失败${NC}"
        fi
    done

    echo -e "\n${BLUE}2. AI 开发平台${NC}"
    for site in "OpenAI" "Hugging Face"; do
        url="${test_sites[$site]}"
        printf "%-20s" "$site"
        if curl -s --connect-timeout 5 "$url" > /dev/null; then
            echo -e "${GREEN}✓ 连接成功${NC}"
            ((success_count++))
        else
            echo -e "${RED}✗ 连接失败${NC}"
        fi
    done

    echo -e "\n${BLUE}3. 包管理器${NC}"
    for site in "Python PyPI" "NPM" "Maven Central" "Ruby Gems" "Golang" "Rust Crates" "CPAN"; do
        url="${test_sites[$site]}"
        printf "%-20s" "$site"
        if curl -s --connect-timeout 5 "$url" > /dev/null; then
            echo -e "${GREEN}✓ 连接成功${NC}"
            ((success_count++))
        else
            echo -e "${RED}✗ 连接失败${NC}"
        fi
    done

    echo -e "\n${BLUE}4. 开发工具${NC}"
    for site in "VS Code Marketplace" "JetBrains" "Docker Hub"; do
        url="${test_sites[$site]}"
        printf "%-20s" "$site"
        if curl -s --connect-timeout 5 "$url" > /dev/null; then
            echo -e "${GREEN}✓ 连接成功${NC}"
            ((success_count++))
        else
            echo -e "${RED}✗ 连接失败${NC}"
        fi
    done

    echo -e "\n${BLUE}5. Linux 发行版${NC}"
    for site in "Ubuntu Packages" "Alpine Linux" "Debian Packages"; do
        url="${test_sites[$site]}"
        printf "%-20s" "$site"
        if curl -s --connect-timeout 5 "$url" > /dev/null; then
            echo -e "${GREEN}✓ 连接成功${NC}"
            ((success_count++))
        else
            echo -e "${RED}✗ 连接失败${NC}"
        fi
    done

    echo -e "\n${BLUE}6. 其他资源${NC}"
    for site in "Stack Overflow" "Google" "Anaconda"; do
        url="${test_sites[$site]}"
        printf "%-20s" "$site"
        if curl -s --connect-timeout 5 "$url" > /dev/null; then
            echo -e "${GREEN}✓ 连接成功${NC}"
            ((success_count++))
        else
            echo -e "${RED}✗ 连接失败${NC}"
        fi
    done
    
    # 显示测试结果统计
    echo -e "\n${BLUE}测试结果统计：${NC}"
    echo "总计测试站点: $total_sites"
    echo "成功连接数: $success_count"
    success_rate=$(( (success_count * 100) / total_sites ))
    echo -e "连接成功率: ${GREEN}${success_rate}%${NC}"
}

# 测试网速
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

# 卸载代理
uninstall_proxy() {
    echo -e "${RED}确定卸载代理吗？这将删除所有代理设置。[y/N]${NC}"
    read -r confirm
    if [[ $confirm =~ ^[Yy]$ ]]; then
        proxy_off
        rm -f /etc/proxychains4.conf
        echo -e "${GREEN}代理已完全卸载${NC}"
        return 0
    else
        echo "取消卸载"
        return 1
    fi
}

# 启动时加载代理设置
load_proxy_settings

# 主循环
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
EOL

chmod +x /usr/local/bin/socks

# 修改 .bashrc 的配置部分
print_message "配置Bash别名..."
cat > ~/.bashrc_proxy << 'EOL'
# 代理设置
proxy_on() {
    export ALL_PROXY=http://127.0.0.1:9093
    export http_proxy=http://127.0.0.1:9093
    export https_proxy=http://127.0.0.1:9093
    echo -e "\033[0;32m代理已启动\033[0m"
}

proxy_off() {
    unset ALL_PROXY
    unset http_proxy
    unset https_proxy
    echo -e "\033[0;31m代理已禁用\033[0m"
}

# 如果环境文件中存在代理设置，则自动启用
if grep -q "http_proxy" /etc/environment; then
    proxy_on
fi
EOL

# 添加到 .bashrc
echo "" >> ~/.bashrc  # 添加一个空行
cat ~/.bashrc_proxy >> ~/.bashrc
rm ~/.bashrc_proxy

# 检查是否以root权限运行
if [ "$EUID" -ne 0 ]; then 
    print_error "请使用root权限运行此脚本"
    exit 1
fi

# 检查依赖
check_dependencies

# 1. 备份原有配置
print_message "开始备份原有配置..."
timestamp=$(date +%Y%m%d_%H%M%S)
BACKUP_FILES=()

# 备份环境变量配置
if [ -f /etc/environment ]; then
    cp /etc/environment "/etc/environment.backup_$timestamp"
    BACKUP_FILES+=("/etc/environment.backup_$timestamp")
fi

# 备份APT代理配置
if [ -f /etc/apt/apt.conf.d/proxy.conf ]; then
    cp /etc/apt/apt.conf.d/proxy.conf "/etc/apt/apt.conf.d/proxy.conf.backup_$timestamp"
    BACKUP_FILES+=("/etc/apt/apt.conf.d/proxy.conf.backup_$timestamp")
fi

# 备份bashrc
if [ -f ~/.bashrc ]; then
    cp ~/.bashrc "~/.bashrc.backup_$timestamp"
    BACKUP_FILES+=("~/.bashrc.backup_$timestamp")
fi

# 2. 复制环境变量配置
print_message "配置环境变量..."
cp etc/environment /etc/
if [ $? -ne 0 ]; then
    print_error "环境变量配置失败"
    exit 1
fi

# 3. 创建并复制APT代理配置
print_message "配置APT代理..."
mkdir -p /etc/apt/apt.conf.d/
cp etc/apt/apt.conf.d/proxy.conf /etc/apt/apt.conf.d/
if [ $? -ne 0 ]; then
    print_error "APT代理配置失败"
    exit 1
fi

# 4. 设置文件权限
print_message "设置文件权限..."
chmod 644 /etc/environment
chmod 644 /etc/apt/apt.conf.d/proxy.conf

# 7. 重新加载配置
print_message "重新加载配置..."
source ~/.bashrc

# 安装完成提示
print_message "安装完成！"
cat << 'EOF'
[INFO] 使用说明：
  1. 基本命令：
     - 在终端中输入 'socks' 启动交互式管理菜单
     - 也可以直接在终端使用 'proxy_on' 和 'proxy_off' 命令

  2. 功能说明：
     - 启动代理：自动配置系统代理并持久化保存
     - 禁用代理：清除所有代理设置
     - 代理状态：显示当前代理配置信息
     - 测试代理：检查与 GitHub/GitLab 的连接
     - 网速测试：测试代理下载速度和延迟
     - 卸载代理：完全移除代理配置

  3. 注意事项：
     - 代理设置在系统重启后仍然有效
     - 如遇问题，可以使用"测试代理"功能检查连接
     - 建议定期使用"网速测试"检查代理性能

[INFO] 备份文件位置：
EOF

# 显示备份文件列表
for backup in "${BACKUP_FILES[@]}"; do
    echo "  - $backup"
done

# 创建代理状态文件
touch /etc/proxy_state
chmod 644 /etc/proxy_state
