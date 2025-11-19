#!/bin/bash
set -euo pipefail  # 脚本出错时立即退出，未定义变量报错，管道命令出错时整体报错

# 0 解析参数（--mode选项，默认local）
echo "=== 解析启动参数 ==="
# 默认模式为本地调试
MODE="local"

# 解析命令行选项
while [[ $# -gt 0 ]]; do
    case "$1" in
        --mode)
            # 检查是否提供了模式值
            if [[ -z "$2" ]]; then
                echo "错误：--mode选项需要指定参数（local或deploy）"
                echo "用法: $0 [--mode local|deploy]"
                exit 1
            fi
            MODE="$2"
            shift 2  # 跳过--mode和其值
            ;;
        *)
            # 未知选项
            echo "错误：未知选项 '$1'"
            echo "用法: $0 [--mode local|deploy]"
            exit 1
            ;;
    esac
done

# 验证模式合法性
if [[ "$MODE" != "local" && "$MODE" != "deploy" ]]; then
    echo "错误：--mode的值必须是local或deploy，当前为'$MODE'"
    echo "用法: $0 [--mode local|deploy]"
    exit 1
fi

echo "启动模式：$MODE"


# 1 确保安装Node.js, Git
echo -e "\n=== 检查基础依赖（Node.js, npm, Git） ==="
check_dependency() {
    local cmd="$1"
    local name="$2"
    if ! command -v "$cmd" &> /dev/null; then
        echo "错误：未检测到$name，请先安装$name后再运行脚本"
        exit 1
    fi
    echo "$name 已安装：$($cmd --version | head -n1)"
}

check_dependency "node" "Node.js"
check_dependency "npm" "npm"
check_dependency "git" "Git"


# 2 安装hexo-cli
echo -e "\n=== 检查并安装hexo-cli ==="
if command -v hexo &> /dev/null; then
    echo "hexo已安装：$(hexo -v | head -n1)"
else
    echo "未检测到hexo，开始安装..."
    if ! npm install -g hexo-cli; then
        echo "hexo安装失败，可能需要管理员权限，请尝试使用sudo重新运行脚本"
        exit 1
    fi
    echo "hexo安装完成：$(hexo -v | head -n1)"
fi


# 3 获取相关目录
echo -e "\n=== 确定目录路径 ==="
# 获取当前脚本所在目录的绝对路径
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
# 脚本所在目录的父目录为工程根目录
ROOT_DIR=$(dirname "$SCRIPT_DIR")
# ROOT_DIR的父目录下的blog目录
BLOG_DIR=$(dirname "$ROOT_DIR")/blog
CONFIG_DIR="$ROOT_DIR/conf"

echo "工程根目录（ROOT_DIR）：$ROOT_DIR"
echo "博客目录（BLOG_DIR）：$BLOG_DIR"


# 4 博客目录初始化
echo -e "\n=== 初始化博客目录 ==="
if [[ -d "$BLOG_DIR" ]]; then
    echo "博客目录已存在，跳过初始化：$BLOG_DIR"
else
    echo "创建并初始化博客目录：$BLOG_DIR"
    mkdir -p "$BLOG_DIR"
    cd "$BLOG_DIR" || {
        echo "无法进入博客目录：$BLOG_DIR"
        exit 1
    }

    echo "执行hexo init..."
    hexo init

    echo "复制配置文件..."
    cp "$CONFIG_DIR/_config.yml" "$BLOG_DIR/_config.yml"

    echo "安装依赖包..."
    npm install -g hexo-cli  # 确保全局安装
    npm install hexo-deployer-git --save
    npm install hexo-renderer-markdown-it --save
    npm install hexo-renderer-markdown-it-plus --save
    npm install hexo-blog-encrypt --save

    echo "博客目录初始化完成"
fi


# 5 博客生成与操作（根据--mode执行对应命令）
echo -e "\n=== 开始博客操作 ==="
cd "$BLOG_DIR" || {
    echo "无法进入博客目录：$BLOG_DIR"
    exit 1
}

# 无论哪种模式，先执行清理和生成
echo "清理缓存文件..."
hexo clean

echo "生成静态文件..."
hexo g

# 根据模式执行对应命令
if [[ "$MODE" == "local" ]]; then
    echo -e "\n启动本地服务器（访问地址：http://localhost:4000）..."
    echo "提示：按 Ctrl+C 可停止本地服务器"
    hexo s  # 本地启动
elif [[ "$MODE" == "deploy" ]]; then
    echo -e "\n开始部署到GitHub..."
    hexo d  # 远程部署
fi

echo -e "\n=== 操作完成（模式：$MODE） ==="
