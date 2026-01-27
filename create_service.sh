#!/bin/bash

#============================================================
# Linux 一键创建 systemd 服务脚本（修复版）
# 功能：创建自定义服务，配置开机自启，并启动服务
# 使用方法：sudo bash create_service.sh
#============================================================

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 打印带颜色的信息（输出到 stderr，避免污染返回值）
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1" >&2
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" >&2
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" >&2
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

# 检查是否以 root 权限运行
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "此脚本需要 root 权限运行！"
        print_info "请使用: sudo $0"
        exit 1
    fi
}

# 检查 systemd 是否可用
check_systemd() {
    if ! command -v systemctl &> /dev/null; then
        print_error "系统不支持 systemd！"
        exit 1
    fi
    print_success "systemd 检测通过"
}

# 验证服务名称
validate_service_name() {
    local name=$1
    if [[ ! $name =~ ^[a-zA-Z][a-zA-Z0-9_-]*$ ]]; then
        print_error "服务名称无效！只能包含字母、数字、下划线和连字符，且必须以字母开头"
        return 1
    fi
    
    if systemctl list-unit-files 2>/dev/null | grep -q "^${name}.service"; then
        print_warning "服务 ${name} 已存在！"
        read -p "是否覆盖？(y/n): " overwrite
        if [[ $overwrite != "y" && $overwrite != "Y" ]]; then
            return 1
        fi
    fi
    return 0
}

# 需要自动补全路径的命令列表
KNOWN_COMMANDS=(
    "python" "python3" "python2"
    "uv" "uvicorn" "gunicorn" "uvx"
    "node" "npm" "npx" "pnpm" "yarn" "bun"
    "java" "dotnet" "ruby" "perl" "php"
    "go" "cargo" "rustc"
    "nginx" "redis-server" "mongod" "mysql" "postgres"
    "pm2" "docker" "podman"
    "pipenv" "poetry" "conda" "pip" "pip3"
    "bash" "sh" "zsh"
)

# 查找命令的完整路径
find_command_path() {
    local cmd=$1
    local cmd_path=""
    
    # 使用 which 查找
    cmd_path=$(which "$cmd" 2>/dev/null)
    if [[ -n "$cmd_path" && -x "$cmd_path" ]]; then
        echo "$cmd_path"
        return 0
    fi
    
    # 使用 command -v 查找
    cmd_path=$(command -v "$cmd" 2>/dev/null)
    if [[ -n "$cmd_path" && -x "$cmd_path" ]]; then
        echo "$cmd_path"
        return 0
    fi
    
    # 在常见路径中查找
    local search_paths=(
        "/usr/bin"
        "/usr/local/bin"
        "/bin"
        "/sbin"
        "/usr/sbin"
        "/usr/local/sbin"
        "/opt/bin"
        "/snap/bin"
        "$HOME/.local/bin"
        "$HOME/.cargo/bin"
        "$HOME/.pyenv/shims"
        "/root/.local/bin"
        "/root/.cargo/bin"
    )
    
    for path in "${search_paths[@]}"; do
        if [[ -x "${path}/${cmd}" ]]; then
            echo "${path}/${cmd}"
            return 0
        fi
    done
    
    return 1
}

# 处理并补全命令路径
process_command() {
    local input_cmd="$1"
    local first_word=""
    local rest_args=""
    
    # 提取第一个词（命令）和剩余参数
    first_word=$(echo "$input_cmd" | awk '{print $1}')
    rest_args=$(echo "$input_cmd" | sed 's/^[^ ]* *//')
    
    # 如果输入只有一个词，rest_args 会等于 first_word，需要清空
    if [[ "$rest_args" == "$first_word" ]]; then
        rest_args=""
    fi
    
    # 如果第一个词已经是绝对路径
    if [[ "$first_word" == /* ]]; then
        if [[ -x "$first_word" ]]; then
            echo "$input_cmd"
            return 0
        else
            print_warning "路径 $first_word 不存在或不可执行"
            echo "$input_cmd"
            return 1
        fi
    fi
    
    # 查找命令路径
    local found_path=""
    found_path=$(find_command_path "$first_word")
    
    if [[ -n "$found_path" ]]; then
        print_success "已自动补全: $first_word -> $found_path"
        if [[ -n "$rest_args" ]]; then
            echo "${found_path} ${rest_args}"
        else
            echo "${found_path}"
        fi
        return 0
    else
        print_warning "无法找到命令 '$first_word' 的路径，将使用原始输入"
        echo "$input_cmd"
        return 1
    fi
}

# 显示支持自动补全的命令列表
show_supported_commands() {
    print_info "支持自动路径补全的命令："
    local line=""
    local count=0
    for cmd in "${KNOWN_COMMANDS[@]}"; do
        line="${line}${cmd}, "
        ((count++))
        if [[ $count -ge 8 ]]; then
            echo "  ${line%, }" >&2
            line=""
            count=0
        fi
    done
    if [[ -n "$line" ]]; then
        echo "  ${line%, }" >&2
    fi
}

# 获取用户输入
get_user_input() {
    local current_dir="${SUDO_PWD:-$(pwd)}"
    
    echo ""
    echo "============================================"
    echo "     Linux systemd 服务创建工具"
    echo "============================================"
    echo ""
    
    # 获取服务名称
    while true; do
        read -p "请输入服务名称: " SERVICE_NAME
        if [[ -z "$SERVICE_NAME" ]]; then
            print_error "服务名称不能为空！"
            continue
        fi
        if validate_service_name "$SERVICE_NAME"; then
            break
        fi
    done
    
    # 显示支持的命令提示
    echo ""
    print_info "提示：输入命令时无需完整路径，脚本会自动补全"
    print_info "例如：python3 app.py 或 uv run app.py"
    echo ""
    show_supported_commands
    echo ""
    
    # 获取启动命令
    while true; do
        read -p "请输入启动命令: " RAW_COMMAND
        if [[ -z "$RAW_COMMAND" ]]; then
            print_error "启动命令不能为空！"
            continue
        fi
        
        # 处理并补全命令路径
        EXEC_COMMAND=$(process_command "$RAW_COMMAND")
        
        echo ""
        print_info "最终启动命令: $EXEC_COMMAND"
        read -p "确认使用此命令？(Y/n): " confirm_cmd
        if [[ $confirm_cmd != "n" && $confirm_cmd != "N" ]]; then
            break
        fi
        echo ""
    done
    
    # 服务描述
    echo ""
    read -p "请输入服务描述（回车跳过）: " SERVICE_DESC
    SERVICE_DESC=${SERVICE_DESC:-"Custom service: ${SERVICE_NAME}"}
    
    # 工作目录默认为当前目录
    echo ""
    print_info "当前目录: $current_dir"
    read -p "请输入工作目录（回车使用当前目录）: " WORKING_DIR
    WORKING_DIR=${WORKING_DIR:-"$current_dir"}
    
    # 验证工作目录
    if [[ ! -d "$WORKING_DIR" ]]; then
        print_warning "目录 $WORKING_DIR 不存在"
        read -p "是否创建该目录？(y/N): " create_dir
        if [[ $create_dir == "y" || $create_dir == "Y" ]]; then
            mkdir -p "$WORKING_DIR"
            print_success "目录已创建"
        fi
    fi
    
    # 运行用户
    echo ""
    read -p "请输入运行用户（默认root）: " RUN_USER
    RUN_USER=${RUN_USER:-"root"}
    
    if ! id "$RUN_USER" &>/dev/null; then
        print_error "用户 $RUN_USER 不存在！将使用 root"
        RUN_USER="root"
    fi
    
    # 选择重启策略
    echo ""
    echo "请选择重启策略："
    echo "  1) always     - 总是重启（推荐）"
    echo "  2) on-failure - 仅在失败时重启"
    echo "  3) no         - 不自动重启"
    read -p "请选择 (1/2/3，默认1): " restart_choice
    case $restart_choice in
        2) RESTART_POLICY="on-failure" ;;
        3) RESTART_POLICY="no" ;;
        *) RESTART_POLICY="always" ;;
    esac
    
    # 环境变量（可选）
    echo ""
    read -p "是否需要设置环境变量？(y/N): " need_env
    ENV_VARS=""
    if [[ $need_env == "y" || $need_env == "Y" ]]; then
        echo "请输入环境变量（格式：KEY=VALUE，每行一个，空行结束）："
        while true; do
            read -p "  > " env_line
            if [[ -z "$env_line" ]]; then
                break
            fi
            ENV_VARS="${ENV_VARS}Environment=${env_line}"$'\n'
        done
    fi
}

# 创建 service 文件
create_service_file() {
    local service_file="/etc/systemd/system/${SERVICE_NAME}.service"
    
    print_info "正在创建服务文件: ${service_file}"
    
    cat > "$service_file" << EOF
[Unit]
Description=${SERVICE_DESC}
After=network.target network-online.target
Wants=network-online.target

[Service]
Type=simple
User=${RUN_USER}
WorkingDirectory=${WORKING_DIR}
ExecStart=${EXEC_COMMAND}
Restart=${RESTART_POLICY}
RestartSec=5
StartLimitInterval=60
StartLimitBurst=3

# 日志配置
StandardOutput=journal
StandardError=journal
SyslogIdentifier=${SERVICE_NAME}
EOF

    # 添加环境变量
    if [[ -n "$ENV_VARS" ]]; then
        echo "" >> "$service_file"
        echo "# 环境变量" >> "$service_file"
        echo -n "$ENV_VARS" >> "$service_file"
    fi

    cat >> "$service_file" << EOF

[Install]
WantedBy=multi-user.target
EOF

    chmod 644 "$service_file"
    
    print_success "服务文件创建成功！"
    
    echo ""
    print_info "生成的服务文件内容："
    echo "-------------------------------------------"
    cat "$service_file"
    echo "-------------------------------------------"
}

# 启用并启动服务
enable_and_start_service() {
    echo ""
    print_info "重新加载 systemd 配置..."
    systemctl daemon-reload
    
    print_info "启用服务开机自启..."
    if systemctl enable "${SERVICE_NAME}.service" 2>/dev/null; then
        print_success "服务已设置为开机自启"
    else
        print_error "设置开机自启失败！"
        return 1
    fi
    
    print_info "启动服务..."
    if systemctl start "${SERVICE_NAME}.service"; then
        sleep 1
        if systemctl is-active --quiet "${SERVICE_NAME}.service"; then
            print_success "服务启动成功！"
        else
            print_warning "服务可能未正常运行，请检查日志"
        fi
    else
        print_error "服务启动失败！"
        echo ""
        print_info "错误日志："
        journalctl -u "${SERVICE_NAME}.service" -n 20 --no-pager
        return 1
    fi
}

# 显示服务状态和使用说明
show_status_and_help() {
    echo ""
    echo "============================================"
    echo "            服务创建完成！"
    echo "============================================"
    echo ""
    print_info "服务状态："
    echo ""
    systemctl status "${SERVICE_NAME}.service" --no-pager -l
    
    echo ""
    echo "============================================"
    echo "           常用管理命令"
    echo "============================================"
    echo ""
    echo -e "  ${GREEN}查看状态:${NC}     systemctl status ${SERVICE_NAME}"
    echo -e "  ${GREEN}启动服务:${NC}     systemctl start ${SERVICE_NAME}"
    echo -e "  ${GREEN}停止服务:${NC}     systemctl stop ${SERVICE_NAME}"
    echo -e "  ${GREEN}重启服务:${NC}     systemctl restart ${SERVICE_NAME}"
    echo -e "  ${GREEN}查看日志:${NC}     journalctl -u ${SERVICE_NAME} -f"
    echo -e "  ${GREEN}最近日志:${NC}     journalctl -u ${SERVICE_NAME} -n 50"
    echo -e "  ${GREEN}禁用自启:${NC}     systemctl disable ${SERVICE_NAME}"
    echo ""
    echo -e "  ${YELLOW}删除服务:${NC}"
    echo "    systemctl stop ${SERVICE_NAME} && \\"
    echo "    systemctl disable ${SERVICE_NAME} && \\"
    echo "    rm /etc/systemd/system/${SERVICE_NAME}.service && \\"
    echo "    systemctl daemon-reload"
    echo ""
    echo -e "  ${BLUE}服务文件:${NC} /etc/systemd/system/${SERVICE_NAME}.service"
    echo ""
}

# 主函数
main() {
    echo ""
    check_root
    check_systemd
    get_user_input
    
    echo ""
    echo "============================================"
    echo "            确认配置信息"
    echo "============================================"
    echo ""
    echo -e "  ${CYAN}服务名称:${NC}  ${SERVICE_NAME}"
    echo -e "  ${CYAN}服务描述:${NC}  ${SERVICE_DESC}"
    echo -e "  ${CYAN}启动命令:${NC}  ${EXEC_COMMAND}"
    echo -e "  ${CYAN}工作目录:${NC}  ${WORKING_DIR}"
    echo -e "  ${CYAN}运行用户:${NC}  ${RUN_USER}"
    echo -e "  ${CYAN}重启策略:${NC}  ${RESTART_POLICY}"
    if [[ -n "$ENV_VARS" ]]; then
        echo -e "  ${CYAN}环境变量:${NC}  已设置"
    fi
    echo ""
    
    read -p "确认创建服务？(Y/n): " confirm
    if [[ $confirm == "n" || $confirm == "N" ]]; then
        print_warning "用户取消操作"
        exit 0
    fi
    
    create_service_file
    enable_and_start_service
    show_status_and_help
}

# 执行主函数
main
