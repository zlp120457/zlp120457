#!/bin/bash

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[0;37m'
NC='\033[0m' # No Color

# 安装目录
INSTALL_DIR="/opt/gemini-proxy-panel"
SCRIPT_NAME="gpanel"
SCRIPT_PATH="/usr/local/bin/${SCRIPT_NAME}"

# 显示ASCII图案和欢迎信息
show_banner() {
    clear
    echo -e "${CYAN}"
    echo "  ██████╗ ██████╗  █████╗ ███╗   ██╗███████╗██╗   "
    echo " ██╔════╝ ██╔══██╗██╔══██╗████╗  ██║██╔════╝██║   "
    echo " ██║  ███╗██████╔╝███████║██╔██╗ ██║█████╗  ██║   "
    echo " ██║   ██║██╔═══╝ ██╔══██║██║╚██╗██║██╔══╝  ██║   "
    echo " ╚██████╔╝██║     ██║  ██║██║ ╚████║███████╗███████╗"
    echo "  ╚═════╝ ╚═╝     ╚═╝  ╚═╝╚═╝  ╚═══╝╚══════╝╚══════╝"
    echo -e "${NC}"
    echo -e "${GREEN}欢迎使用Gemini Proxy Panel管理脚本${NC}"
    echo -e "${WHITE}=================================================${NC}"
}

# 检查是否以root权限运行
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}错误: 此脚本需要root权限运行${NC}"
        echo -e "${YELLOW}请使用 sudo $0 命令运行${NC}"
        exit 1
    fi
}

# 检查安装状态
check_install_status() {
    if [[ -d "$INSTALL_DIR" ]] && [[ -f "$INSTALL_DIR/docker-compose.yml" ]]; then
        echo -e "${GREEN}✓ 已安装${NC}"
        return 0
    else
        echo -e "${RED}✗ 未安装${NC}"
        return 1
    fi
}

# 检查容器运行状态
check_container_status() {
    if command -v docker &> /dev/null; then
        if docker ps --format "table {{.Names}}" | grep -q "gemini-proxy-panel"; then
            echo -e "${GREEN}✓ 容器运行中${NC}"
            return 0
        else
            echo -e "${RED}✗ 容器未运行${NC}"
            return 1
        fi
    else
        echo -e "${YELLOW}⚠ Docker未安装${NC}"
        return 2
    fi
}

# 显示状态信息
show_status() {
    echo -e "\n${BLUE}当前状态:${NC}"
    echo -n "安装状态: "
    check_install_status
    echo -n "容器状态: "
    check_container_status
}

# 安装依赖
install_dependencies() {
    echo -e "${YELLOW}正在安装依赖...${NC}"
    
    # 检测系统类型并安装依赖
    if command -v apt-get &> /dev/null; then
        apt-get update -qq
        apt-get install -y curl wget git jq net-tools >/dev/null 2>&1
    elif command -v yum &> /dev/null; then
        yum install -y curl wget git jq net-tools >/dev/null 2>&1
    elif command -v dnf &> /dev/null; then
        dnf install -y curl wget git jq net-tools >/dev/null 2>&1
    else
        echo -e "${RED}不支持的系统类型${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}依赖安装完成${NC}"
}

# 安装Docker
install_docker() {
    echo -e "${YELLOW}正在检查Docker...${NC}"
    
    if ! command -v docker &> /dev/null; then
        echo -e "${YELLOW}Docker未安装，正在安装...${NC}"
        curl -fsSL https://get.docker.com | sh
        systemctl start docker
        systemctl enable docker
        echo -e "${GREEN}Docker安装完成${NC}"
    else
        echo -e "${GREEN}Docker已安装${NC}"
    fi
    
    # 检查docker-compose
    if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
        echo -e "${YELLOW}正在安装Docker Compose...${NC}"
        curl -SL https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64 -o /usr/local/bin/docker-compose
        chmod +x /usr/local/bin/docker-compose
        echo -e "${GREEN}Docker Compose安装完成${NC}"
    else
        echo -e "${GREEN}Docker Compose已安装${NC}"
    fi
}

# 获取服务器外网IP
get_external_ip() {
    local ip=$(curl -s -4 ifconfig.me 2>/dev/null || curl -s -4 icanhazip.com 2>/dev/null || curl -s -4 ident.me 2>/dev/null)
    if [[ -z "$ip" ]]; then
        ip=$(hostname -I | awk '{print $1}')
    fi
    echo "$ip"
}

# 安装Gemini Proxy Panel
install_panel() {
    echo -e "${CYAN}开始安装 Gemini Proxy Panel...${NC}"
    
    # 安装依赖
    install_dependencies
    
    # 安装Docker
    install_docker
    
    # 创建安装目录
    echo -e "${YELLOW}创建安装目录...${NC}"
    mkdir -p "$INSTALL_DIR"
    cd "$INSTALL_DIR"
    
    # 设置管理密码
    while true; do
        echo -e "${CYAN}请输入管理密码:${NC}"
        read -s admin_password
        echo
        if [[ -z "$admin_password" ]]; then
            echo -e "${RED}密码不能为空，请重新输入${NC}"
        else
            break
        fi
    done
    
    # 设置端口
    echo -e "${CYAN}是否使用默认端口3000? [Y/n]:${NC}"
    read -r use_default_port
    use_default_port=${use_default_port:-y}
    
    if [[ "$use_default_port" =~ ^[Nn]$ ]]; then
        echo -e "${CYAN}请输入自定义端口:${NC}"
        read -r custom_port
        port=${custom_port:-3000}
    else
        port=3000
    fi
    
    # 设置外部访问
    echo -e "${CYAN}是否允许外部访问? [Y/n]:${NC}"
    read -r allow_external
    allow_external=${allow_external:-y}
    
    # 生成.env文件
    echo -e "${YELLOW}生成配置文件...${NC}"
    cat > .env <<EOF
ADMIN_PASSWORD=${admin_password}
PORT=${port}
EOF
    
    # 生成docker-compose.yml文件
    if [[ "$allow_external" =~ ^[Nn]$ ]]; then
        # 仅本地访问
        cat > docker-compose.yml <<EOF
version: '3.8' 
services:
  app:
    image: dreamhartley705/gemini-proxy-panel:latest
    container_name: gemini-proxy-panel
    ports:
      - "127.0.0.1:${port}:${port}"
    env_file:
      - .env
    volumes:
      - ./data:/usr/src/app/data
    restart: unless-stopped
EOF
    else
        # 允许外部访问
        cat > docker-compose.yml <<EOF
version: '3.8' 
services:
  app:
    image: dreamhartley705/gemini-proxy-panel:latest
    container_name: gemini-proxy-panel
    ports:
      - "${port}:${port}"
    env_file:
      - .env
    volumes:
      - ./data:/usr/src/app/data
    restart: unless-stopped
EOF
    fi
    
    # 启动容器
    echo -e "${YELLOW}启动容器...${NC}"
    if command -v docker-compose &> /dev/null; then
        docker-compose up -d
    else
        docker compose up -d
    fi
    
    # 等待容器启动
    sleep 3
    
    # 显示访问地址
    echo -e "${GREEN}安装完成！${NC}"
    if [[ "$allow_external" =~ ^[Nn]$ ]]; then
        echo -e "${CYAN}访问地址: http://127.0.0.1:${port}${NC}"
        echo -e "${YELLOW}注意: 仅本地访问${NC}"
    else
        external_ip=$(get_external_ip)
        echo -e "${CYAN}访问地址: http://${external_ip}:${port}${NC}"
        echo -e "${CYAN}本地访问: http://127.0.0.1:${port}${NC}"
    fi
    echo -e "${CYAN}管理密码: 您设置的密码${NC}"
}

# 启动容器
start_container() {
    if ! check_install_status > /dev/null; then
        echo -e "${RED}错误: Gemini Proxy Panel未安装${NC}"
        return 1
    fi
    
    cd "$INSTALL_DIR"
    echo -e "${YELLOW}正在启动容器...${NC}"
    
    if command -v docker-compose &> /dev/null; then
        docker-compose up -d
    else
        docker compose up -d
    fi
    
    echo -e "${GREEN}容器启动成功${NC}"
}

# 停止容器
stop_container() {
    if ! check_install_status > /dev/null; then
        echo -e "${RED}错误: Gemini Proxy Panel未安装${NC}"
        return 1
    fi
    
    cd "$INSTALL_DIR"
    echo -e "${YELLOW}正在停止容器...${NC}"
    
    if command -v docker-compose &> /dev/null; then
        docker-compose down
    else
        docker compose down
    fi
    
    echo -e "${GREEN}容器停止成功${NC}"
}

# 重启容器
restart_container() {
    if ! check_install_status > /dev/null; then
        echo -e "${RED}错误: Gemini Proxy Panel未安装${NC}"
        return 1
    fi
    
    cd "$INSTALL_DIR"
    echo -e "${YELLOW}正在重启容器...${NC}"
    
    if command -v docker-compose &> /dev/null; then
        docker-compose restart
    else
        docker compose restart
    fi
    
    echo -e "${GREEN}容器重启成功${NC}"
}

# 注册系统命令
register_command() {
    if [[ ! -f "$SCRIPT_PATH" ]]; then
        echo -e "${YELLOW}注册系统命令...${NC}"
        cp "$0" "$SCRIPT_PATH"
        chmod +x "$SCRIPT_PATH"
        echo -e "${GREEN}命令注册成功，您可以使用 'gpanel' 命令启动管理脚本${NC}"
    fi
}

# 显示菜单
show_menu() {
    echo -e "\n${BLUE}请选择操作:${NC}"
    echo "1. 安装 Gemini Proxy Panel"
    echo "2. 启动 Gemini Proxy Panel 容器"
    echo "3. 停止 Gemini Proxy Panel 容器"
    echo "4. 重启 Gemini Proxy Panel 容器"
    echo "0. 退出"
    echo -e "${CYAN}请输入选项 [0-4]:${NC}"
}

# 主函数
main() {
    check_root
    register_command
    
    while true; do
        show_banner
        show_status
        show_menu
        
        read -r choice
        
        case $choice in
            1)
                if check_install_status > /dev/null; then
                    echo -e "${YELLOW}Gemini Proxy Panel已安装${NC}"
                    echo -n "按任意键继续..."
                    read -n 1
                else
                    install_panel
                    echo -n "按任意键继续..."
                    read -n 1
                fi
                ;;
            2)
                start_container
                echo -n "按任意键继续..."
                read -n 1
                ;;
            3)
                stop_container
                echo -n "按任意键继续..."
                read -n 1
                ;;
            4)
                restart_container
                echo -n "按任意键继续..."
                read -n 1
                ;;
            0)
                echo -e "${GREEN}感谢使用，再见！${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}无效选项，请重新选择${NC}"
                sleep 2
                ;;
        esac
    done
}

# 执行主函数
main
