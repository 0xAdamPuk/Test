#!/bin/bash

#============================================================
# Linux 一键创建 systemd 服务脚本（优化版）
# 功能：创建自定义服务，配置开机自启，并启动服务
# 优化：自动补全命令路径，工作目录默认为当前目录
# 使用方法：sudo bash create_service.sh
#============================================================

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 打印带颜色的信息
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_debug() {
    echo -e "${CYAN}[DEBUG]${NC} $1"
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
    # 服务名只能包含字母、数字、下划线和连字符
    if [[ ! $name =~ ^[a-zA-Z][a-zA-Z0-9_-]*$ ]]; then
        print_error "服务名称无效！只能包含字母、数字、下划线和连字符，且必须以字母开头"
        return 1
    fi
    
    # 检查服务是否已存在
    if systemctl list-unit-files | grep -q "^${name}.service"; then
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
    "python"
    "python3"
    "python2"
    "uv"
    "uvicorn"
    "gunicorn"
    "node"
    "npm"
    "npx"
    "java"
    "dotnet"
    "ruby"
    "perl"
    "php"
    "go"
    "cargo"
    "rustc"
    "nginx"
    "redis-server"
    "mongod"
    "mysql"
    "postgres"
    "pm2"
    "docker"
    "podman"
    "pipenv"
    "poetry"
    "conda"
    "pip"
    "pip3"
    "bash"
    "sh"
    "zsh"
)

# 查找命令的完整路径
find_command_path() {
    local cmd=$1
    local cmd_path=""
    
    # 使用 which 查找
    cmd_path=$(which "$cmd" 2>/dev/null)
    if [[ -n "$cmd_path" ]]; then
        echo "$cmd_path"
        return 0
    fi
    
    # 使用 command -v 查找
    cmd_path=$(command -v "$cmd" 2>/dev/null)
    if [[ -n "$cmd_path" ]]; then
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
        "$HOME/.nvm/versions/node/*/bin"
        "/root/.local/bin"
        "/root/.cargo/bin"
    )
    
    for path in "${search_paths[@]}"; do
        # 处理通配符路径
        for expanded_path in $path; do
            if [[ -x "${expanded_path}/${cmd}" ]]; then
                echo "${expanded_path}/${cmd}"
                return 0
            fi
        done
    done
    
    return 1
}

# 检查是否是已知命令
is_known_command() {
    local cmd=$1
    for known_cmd in "${KNOWN_COMMANDS[@]}"; do
        if [[ "$cmd" == "$known_cmd" ]]; then
            return 0
        fi
    done
    return 1
}

# 处理并补全命令路径
process_command() {
    local input_cmd="$1"
    local result=""
    local first_word=""
    local rest_args=""
    
    # 提取第一个词（命令）和剩余参数
    first_word=$(echo "$input_cmd" | awk '{print $1}')
    rest_args=$(echo "$input_cmd" | cut -d' ' -f2- -s)
    
    # 如果第一个词已经是绝对路径，直接返回
    if [[ "$first_word" == /* ]]; then
        # 检查路径是否存在且可执行
        if [[ -x "$first_word" ]]; then
            echo "$input_cmd"
            return 0
        else
            print_warning "路径 $first_word 不存在或不可执行"
            echo "$input_cmd"
            return 1
        fi
    fi
    
    # 检查是否是已知命令或尝试查找路径
    local found_path=""
    found_path=$(find_command_path "$first_word")
    
    if [[ -n "$found_path" ]]; then
        if [[ -n "$rest_args" ]]; then
            result="${found_path} ${rest_args}"
        else
            result="${found_path}"
        fi
        
        if [[ "$found_path" != "$first_word" ]]; then
            print_success "已自动补全命令路径: $first_word -> $found_path"
        fi
        echo "$result"
        return 0
    else
        print_warning "无法找到命令 '$first_word' 的路径，将使用原始输入"
        echo "$input_cmd"
        return 1
    fi
}

# 处理命令中的所有可能需要补全的路径
process_full_command() {
    local input_cmd="$1"
    local processed_cmd=""
    local words=()
    local i=0
    
    # 将命令分割成数组，保留引号内的空格
    eval "words=($input_cmd)" 2>/dev/null || words=($input_cmd)
    
    for word in "${words[@]}"; do
        if [[ $i -eq 0 ]]; then
            # 第一个词是主命令
            if [[ "$word" != /* ]]; then
                local found_path=$(find_command_path "$word")
                if [[ -n "$found_path" ]]; then
                    if [[ "$found_path" != "$word" ]]; then
                        print_success "已自动补全: $word -> $found_path"
                    fi
                    processed_cmd="$found_path"
                else
                    processed_cmd="$word"
                fi
            else
                processed_cmd="$word"
            fi
        else
            # 后续参数，检查是否是子命令（如 uv run, npm start 等）
            processed_cmd="$processed_cmd $word"
        fi
        ((i++))
    done
    
    echo "$processed_cmd"
}

# 显示支持自动补全的命令列表
show_supported_commands() {
    echo ""
    print_info "支持自动路径补全的命令："
    echo "  ${KNOWN_COMMANDS[*]}" | fold -s -w 60 | sed 's/^/  /'
    echo ""
}

# 获取用户输入
get_user_input() {
    # 获取当前目录（在提权前保存的原始目录）
    local current_dir="${SUDO_PWD:-$(pwd)}"
    
    echo ""
    echo "============================================"
    echo "     Linux systemd 服务创建工具 (优化版)"
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
    print_info "例如：python3 /path/to/app.py 或 uv run app.py"
    show_supported_commands
    
    # 获取启动命令
    while true; do
        read -p "请输入启动命令: " RAW_COMMAND
        if [[ -z "$RAW_COMMAND" ]]; then
            print_error "启动命令不能为空！"
            continue
        fi
        
        # 处理并补全命令路径
        EXEC_COMMAND=$(process_full_command "$RAW_COMMAND")
        
        echo ""
        print_info "最终命令: $EXEC_COMMAND"
        read -p "确认使用此命令？(y/n，默认y): " confirm_cmd
        if [[ $confirm_cmd != "n" && $confirm_cmd != "N" ]]; then
            break
        fi
        echo ""
    done
    
    # 获取可选参数
    read -p "请输入服务描述（可选，直接回车跳过）: " SERVICE_DESC
    SERVICE_DESC=${SERVICE_DESC:-"Custom service created by script"}
    
    # 工作目录默认为当前目录
    echo ""
    print_info "当前目录: $current_dir"
    read -p "请输入工作目录（直接回车使用当前目录）: " WORKING_DIR
    WORKING_DIR=${WORKING_DIR:-"$current_dir"}
    
    # 验证工作目录
    if [[ ! -d "$WORKING_DIR" ]]; then
        print_warning "目录 $WORKING_DIR 不存在"
        read -p "是否创建该目录？(y/n): " create_dir
        if [[ $create_dir == "y" || $create_dir == "Y" ]]; then
            mkdir -p "$WORKING_DIR"
            print_success "目录已创建"
        fi
    fi
    
    read -p "请输入运行用户（可选，默认root）: " RUN_USER
    RUN_USER=${RUN_USER:-"root"}
    
    # 验证用户是否存在
    if ! id "$RUN_USER" &>/dev/null; then
        print_error "用户 $RUN_USER 不存在！"
        read -p "请重新输入运行用户（默认root）: " RUN_USER
        RUN_USER=${RUN_USER:-"root"}
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
    read -p "是否需要设置环境变量？(y/n，默认n): " need_env
    ENV_VARS=""
    if [[ $need_env == "y" || $need_env == "Y" ]]; then
        echo "请输入环境变量（格式：KEY=VALUE，每行一个，输入空行结束）："
        while true; do
            read -p "  > " env_line
            if [[ -z "$env_line" ]]; then
                break
            fi
            ENV_VARS="${ENV_VARS}Environment=${env_line}\n"
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

# 标准输出和错误输出到日志
StandardOutput=journal
StandardError=journal
SyslogIdentifier=${SERVICE_NAME}
EOF

    # 添加环境变量
    if [[ -n "$ENV_VARS" ]]; then
        echo -e "\n# 环境变量" >> "$service_file"
        echo -e "$ENV_VARS" >> "$service_file"
    fi

    # 添加 Install 部分
    cat >> "$service_file" << EOF

[Install]
WantedBy=multi-user.target
EOF

    # 设置权限
    chmod 644 "$service_file"
    
    print_success "服务文件创建成功！"
    
    # 显示生成的服务文件内容
    echo ""
    print_info "生成的服务文件内容："
    echo "-------------------------------------------"
    cat "$service_file"
    echo "-------------------------------------------"
}

# 启用并启动服务
enable_and_start_service() {
    print_info "重新加载 systemd 配置..."
    systemctl daemon-reload
    
    print_info "启用服务开机自启..."
    if systemctl enable "${SERVICE_NAME}.service"; then
        print_success "服务已设置为开机自启"
    else
        print_error "设置开机自启失败！"
        return 1
    fi
    
    print_info "启动服务..."
    if systemctl start "${SERVICE_NAME}.service"; then
        # 等待一秒检查服务状态
        sleep 1
        if systemctl is-active --quiet "${SERVICE_NAME}.service"; then
            print_success "服务启动成功！"
        else
            print_warning "服务可能未正常运行，请检查日志"
        fi
    else
        print_error "服务启动失败！"
        print_info "请检查日志: journalctl -u ${SERVICE_NAME}.service -n 50"
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
    echo -e "  ${GREEN}查看状态:${NC}    systemctl status ${SERVICE_NAME}"
    echo -e "  ${GREEN}启动服务:${NC}    systemctl start ${SERVICE_NAME}"
    echo -e "  ${GREEN}停止服务:${NC}    systemctl stop ${SERVICE_NAME}"
    echo -e "  ${GREEN}重启服务:${NC}    systemctl restart ${SERVICE_NAME}"
    echo -e "  ${GREEN}重载配置:${NC}    systemctl reload ${SERVICE_NAME}"
    echo -e "  ${GREEN}查看日志:${NC}    journalctl -u ${SERVICE_NAME} -f"
    echo -e "  ${GREEN}查看最近日志:${NC} journalctl -u ${SERVICE_NAME} -n 100"
    echo -e "  ${GREEN}禁用自启:${NC}    systemctl disable ${SERVICE_NAME}"
    echo -e "  ${GREEN}启用自启:${NC}    systemctl enable ${SERVICE_NAME}"
    echo ""
    echo -e "  ${YELLOW}删除服务:${NC}"
    echo "    systemctl stop ${SERVICE_NAME}"
    echo "    systemctl disable ${SERVICE_NAME}"
    echo "    rm /etc/systemd/system/${SERVICE_NAME}.service"
    echo "    systemctl daemon-reload"
    echo ""
    echo -e "  ${BLUE}服务文件位置:${NC} /etc/systemd/system/${SERVICE_NAME}.service"
    echo -e "  ${BLUE}编辑服务文件:${NC} nano /etc/systemd/system/${SERVICE_NAME}.service"
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
    echo -e "  ${CYAN}服务名称:${NC}    ${SERVICE_NAME}"
    echo -e "  ${CYAN}服务描述:${NC}    ${SERVICE_DESC}"
    echo -e "  ${CYAN}启动命令:${NC}    ${EXEC_COMMAND}"
    echo -e "  ${CYAN}工作目录:${NC}    ${WORKING_DIR}"
    echo -e "  ${CYAN}运行用户:${NC}    ${RUN_USER}"
    echo -e "  ${CYAN}重启策略:${NC}    ${RESTART_POLICY}"
    if [[ -n "$ENV_VARS" ]]; then
        echo -e "  ${CYAN}环境变量:${NC}    已设置"
    fi
    echo ""
    
    read -p "确认创建服务？(y/n): " confirm
    if [[ $confirm != "y" && $confirm != "Y" ]]; then
        print_warning "用户取消操作"
        exit 0
    fi
    
    create_service_file
    enable_and_start_service
    show_status_and_help
}

# 执行主函数
main
