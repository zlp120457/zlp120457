#!/bin/bash

# Gemini Proxy Panel Management Script
# Author: Gemini
# Version: 1.0.0

# --- 彩色输出定义 ---
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# --- 全局变量 ---
INSTALL_DIR="/opt/gemini-proxy-panel"
DOCKER_COMPOSE_YML="$INSTALL_DIR/docker-compose.yml"
ENV_FILE="$INSTALL_DIR/.env"
CONTAINER_NAME="gemini-proxy-panel"
SCRIPT_SELF_PATH="/usr/local/bin/gpanel"

# --- 函数定义 ---

# 检查是否以root用户运行
check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        echo -e "${RED}错误：此脚本必须以root用户权限运行。${NC}"
        echo -e "${YELLOW}请尝试使用 'sudo -i' 命令切换到root账户后再执行。${NC}"
        exit 1
    fi
}

# 检查操作系统并安装必要的依赖
check_os_and_install_deps() {
    echo -e "${BLUE}正在检查并安装依赖...${NC}"
    if command -v apt-get &> /dev/null; then
        # Debian/Ubuntu
        apt-get update -y > /dev/null 2>&1
        apt-get install -y curl wget socat > /dev/null 2>&1
    elif command -v yum &> /dev/null; then
        # CentOS/RHEL
        yum install -y curl wget socat > /dev/null 2>&1
    else
        echo -e "${RED}未能识别的操作系统，请手动安装 curl, wget, socat。${NC}"
        exit 1
    fi
    echo -e "${GREEN}依赖检查完成。${NC}"
}

# 检查并安装Docker
check_docker() {
    if command -v docker &> /dev/null; then
        echo -e "${GREEN}Docker 已安装。${NC}"
    else
        echo -e "${YELLOW}未检测到Docker，正在尝试自动安装...${NC}"
        curl -fsSL https://get.docker.com -o get-docker.sh
        sh get-docker.sh
        rm get-docker.sh
        if [ $? -ne 0 ]; then
            echo -e "${RED}Docker 安装失败，请访问 https://www.docker.com/ 手动安装。${NC}"
            exit 1
        fi
        systemctl start docker
        systemctl enable docker
        echo -e "${GREEN}Docker 安装并启动成功。${NC}"
    fi

    # 检查 Docker Compose
    if command -v docker-compose &> /dev/null || docker compose version &> /dev/null; then
        echo -e "${GREEN}Docker Compose 已可用。${NC}"
    else
        echo -e "${RED}Docker Compose 安装失败，请检查Docker安装过程。${NC}"
        exit 1
    fi
}

# 获取 Docker Compose 命令
get_docker_compose_cmd() {
    if docker compose version &>/dev/null; then
        echo "docker compose"
    elif command -v docker-compose &>/dev/null; then
        echo "docker-compose"
    else
        echo ""
    fi
}

# 显示ASCII Art
show_ascii_art() {
    echo -e "${BLUE}"
    echo "  ██████╗ ██████╗  █████╗ ███╗   ██╗███████╗██╗   "
    echo " ██╔════╝ ██╔══██╗██╔══██╗████╗  ██║██╔════╝██║   "
    echo " ██║  ███╗██████╔╝███████║██╔██╗ ██║█████╗  ██║   "
    echo " ██║   ██║██╔═══╝ ██╔══██║██║╚██╗██║██╔══╝  ██║   "
    echo " ╚██████╔╝██║     ██║  ██║██║ ╚████║███████╗███████╗"
    echo "  ╚═════╝ ╚═╝     ╚═╝  ╚═╝╚═╝  ╚═══╝╚══════╝╚══════╝"
    echo -e "${NC}"
}

# 获取当前状态
show_status() {
    echo "--------------------------------------------------"
    # 检查安装状态
    if [ -d "$INSTALL_DIR" ]; then
        echo -e "安装状态: ${GREEN}已安装${NC} (路径: $INSTALL_DIR)"
    else
        echo -e "安装状态: ${RED}未安装${NC}"
    fi

    # 检查容器运行状态
    if [ -d "$INSTALL_DIR" ]; then
        local running_container_id
        running_container_id=$(docker ps -q -f "name=^${CONTAINER_NAME}$")
        if [ -n "$running_container_id" ]; then
            echo -e "容器状态: ${GREEN}正在运行${NC}"
        else
            local stopped_container_id
            stopped_container_id=$(docker ps -aq -f "name=^${CONTAINER_NAME}$")
            if [ -n "$stopped_container_id" ]; then
                echo -e "容器状态: ${YELLOW}已停止${NC}"
            else
                echo -e "容器状态: ${RED}未创建${NC}"
            fi
        fi
    fi
    echo "--------------------------------------------------"
}

# 安装函数
install_panel() {
    if [ -d "$INSTALL_DIR" ]; then
        read -p "$(echo -e ${YELLOW}"Gemini Proxy Panel似乎已安装，是否要覆盖安装？(y/n): "${NC})" confirm
        if [[ "$confirm" != "y" ]]; then
            echo -e "${RED}安装已取消。${NC}"
            return
        fi
        # 停止并移除旧容器
        local DOCKER_COMPOSE_CMD
        DOCKER_COMPOSE_CMD=$(get_docker_compose_cmd)
        if [ -n "$DOCKER_COMPOSE_CMD" ] && [ -f "$DOCKER_COMPOSE_YML" ]; then
            cd "$INSTALL_DIR" && $DOCKER_COMPOSE_CMD down --remove-orphans > /dev/null 2>&1
        fi
        rm -rf "$INSTALL_DIR"
    fi

    echo -e "${BLUE}--- 开始安装 Gemini Proxy Panel ---${NC}"
    check_os_and_install_deps
    check_docker

    mkdir -p "$INSTALL_DIR"
    echo -e "${GREEN}安装目录 '$INSTALL_DIR' 创建成功。${NC}"

    # 设置管理员密码
    local admin_password
    while true; do
        read -s -p "请输入您的管理后台密码: " admin_password
        echo
        read -s -p "请再次输入密码以确认: " admin_password_confirm
        echo
        if [ "$admin_password" == "$admin_password_confirm" ]; then
            if [ -z "$admin_password" ]; then
                echo -e "${RED}密码不能为空，请重新输入。${NC}"
            else
                break
            fi
        else
            echo -e "${RED}两次输入的密码不匹配，请重新输入。${NC}"
        fi
    done
    echo "ADMIN_PASSWORD=$admin_password" > "$ENV_FILE"
    echo -e "${GREEN}管理密码已设置。${NC}"

    # 设置端口
    local port="3000"
    local custom_port
    read -p "$(echo -e ${YELLOW}"是否使用默认端口 3000? (y/n) [默认: y]: "${NC})" use_default_port
    if [[ "$use_default_port" == "n" ]]; then
        while true; do
            read -p "请输入自定义端口 (1-65535): " custom_port
            if [[ "$custom_port" =~ ^[0-9]+$ ]] && [ "$custom_port" -ge 1 ] && [ "$custom_port" -le 65535 ]; then
                port=$custom_port
                echo "PORT=$port" >> "$ENV_FILE"
                echo -e "${GREEN}已使用自定义端口: $port${NC}"
                break
            else
                echo -e "${RED}无效的端口号，请输入1-65535之间的数字。${NC}"
            fi
        done
    else
        echo -e "${GREEN}已使用默认端口: 3000${NC}"
    fi

    # 设置外部访问
    local listen_ip="0.0.0.0"
    read -p "$(echo -e ${YELLOW}"是否允许外部IP访问面板? (y/n) [默认: y]: "${NC})" allow_external
    if [[ "$allow_external" == "n" ]]; then
        listen_ip="127.0.0.1"
        echo -e "${GREEN}已设置为仅本地访问。${NC}"
    else
        echo -e "${GREEN}已设置为允许外部访问。${NC}"
    fi

    # 生成 docker-compose.yml 文件
    cat > "$DOCKER_COMPOSE_YML" <<EOF
version: '3.8'
services:
  app:
    image: dreamhartley705/gemini-proxy-panel:latest
    container_name: ${CONTAINER_NAME}
    restart: always
    ports:
      - "${listen_ip}:${port}:${port}"
    env_file:
      - .env
    volumes:
      - ./data:/usr/src/app/data
EOF
    echo -e "${GREEN}docker-compose.yml 文件生成成功。${NC}"

    # 启动容器
    echo -e "${BLUE}正在拉取镜像并启动容器，请稍候...${NC}"
    local DOCKER_COMPOSE_CMD
    DOCKER_COMPOSE_CMD=$(get_docker_compose_cmd)
    if [ -z "$DOCKER_COMPOSE_CMD" ]; then
        echo -e "${RED}找不到 Docker Compose 命令，无法启动容器。${NC}"
        exit 1
    fi
    cd "$INSTALL_DIR" && $DOCKER_COMPOSE_CMD up -d
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}--- Gemini Proxy Panel 安装成功！ ---${NC}"
        local public_ip
        public_ip=$(curl -s http://ipv4.icanhazip.com)
        echo -e "您的面板访问地址是: ${YELLOW}http://${public_ip}:${port}${NC}"
        if [ "$listen_ip" == "127.0.0.1" ]; then
            echo -e "请注意：您已设置为仅本地访问，请使用 ${YELLOW}http://127.0.0.1:${port}${NC} 或通过SSH隧道访问。"
        fi
    else
        echo -e "${RED}容器启动失败，请检查日志。${NC}"
        echo -e "您可以尝试在目录 ${YELLOW}${INSTALL_DIR}${NC} 中运行 '${YELLOW}${DOCKER_COMPOSE_CMD} logs${NC}' 来查看错误信息。"
    fi
}

# 启动容器
start_panel() {
    if [ ! -f "$DOCKER_COMPOSE_YML" ]; then
        echo -e "${RED}错误：找不到配置文件，请先安装。${NC}"
        return
    fi
    echo -e "${BLUE}正在启动容器...${NC}"
    local DOCKER_COMPOSE_CMD
    DOCKER_COMPOSE_CMD=$(get_docker_compose_cmd)
    cd "$INSTALL_DIR" && $DOCKER_COMPOSE_CMD start
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}容器启动成功。${NC}"
    else
        echo -e "${RED}容器启动失败。${NC}"
    fi
}

# 停止容器
stop_panel() {
    if [ ! -f "$DOCKER_COMPOSE_YML" ]; then
        echo -e "${RED}错误：找不到配置文件，请先安装。${NC}"
        return
    fi
    echo -e "${BLUE}正在停止容器...${NC}"
    local DOCKER_COMPOSE_CMD
    DOCKER_COMPOSE_CMD=$(get_docker_compose_cmd)
    cd "$INSTALL_DIR" && $DOCKER_COMPOSE_CMD stop
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}容器停止成功。${NC}"
    else
        echo -e "${RED}容器停止失败。${NC}"
    fi
}

# 重启容器
restart_panel() {
    if [ ! -f "$DOCKER_COMPOSE_YML" ]; then
        echo -e "${RED}错误：找不到配置文件，请先安装。${NC}"
        return
    fi
    echo -e "${BLUE}正在重启容器...${NC}"
    local DOCKER_COMPOSE_CMD
    DOCKER_COMPOSE_CMD=$(get_docker_compose_cmd)
    cd "$INSTALL_DIR" && $DOCKER_COMPOSE_CMD restart
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}容器重启成功。${NC}"
    else
        echo -e "${RED}容器重启失败。${NC}"
    fi
}

# 主菜单
main_menu() {
    clear
    show_ascii_art
    echo -e "欢迎使用 ${GREEN}Gemini Proxy Panel${NC} 管理脚本"
    show_status

    echo -e "${YELLOW}请选择要执行的操作:${NC}"
    echo "1. 安装 Gemini Proxy Panel"
    echo "2. 启动 Gemini Proxy Panel"
    echo "3. 停止 Gemini Proxy Panel"
    echo "4. 重启 Gemini Proxy Panel"
    echo "--------------------------------------------------"
    echo "0. 退出脚本"
    
    read -p "请输入选项 [0-4]: " choice

    case $choice in
        1) install_panel ;;
        2) start_panel ;;
        3) stop_panel ;;
        4) restart_panel ;;
        0) exit 0 ;;
        *) echo -e "${RED}无效的输入，请输入 0-4 之间的数字。${NC}" ;;
    esac
}

# --- 脚本主入口 ---

# 检查root权限
check_root

# 如果脚本不是通过 'gpanel' 命令执行的，则进行安装
# 这段逻辑使得用户可以通过 curl | bash 的方式首次运行脚本
# 脚本会自我复制并创建软链接，然后再次执行
if [ ! -f "$SCRIPT_SELF_PATH" ] || [ "$0" != "$SCRIPT_SELF_PATH" ]; then
    # 复制自身到目标路径
    cp "$0" "$SCRIPT_SELF_PATH"
    chmod +x "$SCRIPT_SELF_PATH"
    echo -e "${GREEN}管理命令 'gpanel' 已安装成功！${NC}"
    echo -e "${YELLOW}您现在可以随时在终端输入 'gpanel' 来运行此管理面板。${NC}"
    echo -e "${BLUE}正在进入管理面板...${NC}"
    sleep 2
    # 执行新路径的脚本，并传递所有参数
    exec "$SCRIPT_SELF_PATH" "$@"
    exit 0
fi


# 循环显示主菜单
while true; do
    main_menu
    read -p "$(echo -e ${BLUE}"按 [Enter] 键返回主菜单..."${NC})"
done
