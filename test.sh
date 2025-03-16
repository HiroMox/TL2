#!/bin/bash

# 安装 Docker 和 Docker Compose
if ! command -v docker &> /dev/null; then
    echo "Docker 未安装，正在安装..."
    curl -fsSL https://get.docker.com | bash
    systemctl enable docker
    systemctl start docker
    echo "Docker 安装完成"
else
    echo "Docker 已安装"
fi

# 确保 Docker Compose 可用
if ! docker compose version &> /dev/null; then
    echo "Docker Compose 未安装，正在安装..."
    DOCKER_CONFIG=${DOCKER_CONFIG:-/usr/local/lib/docker}
    mkdir -p $DOCKER_CONFIG/cli-plugins
    curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o $DOCKER_CONFIG/cli-plugins/docker-compose
    chmod +x $DOCKER_CONFIG/cli-plugins/docker-compose
    ln -s $DOCKER_CONFIG/cli-plugins/docker-compose /usr/bin/docker-compose
    echo "Docker Compose 安装完成"
else
    echo "Docker Compose 已安装"
fi

# 配置 Docker 镜像加速器
mkdir -p /etc/docker
cat > /etc/docker/daemon.json <<EOF
{
    "registry-mirrors": [
        "https://docker.dadunode.com",
        "https://noohub.ru",
        "https://huecker.io",
        "https://dockerhub.timeweb.cloud",
        "https://docker.rainbond.cc",
        "https://docker.1ms.run",
        "https://docker.m.daocloud.io"
    ]
}
EOF

# 重启 Docker 使配置生效
systemctl restart docker

echo "Docker 镜像加速器配置完成"

# 配置 limits.conf
LIMITS_CONF="/etc/security/limits.conf"
if ! grep -q "^\* soft nofile 524288" "$LIMITS_CONF"; then
    echo "* soft nofile 524288" >> "$LIMITS_CONF"
fi
if ! grep -q "^\* hard nofile 524288" "$LIMITS_CONF"; then
    echo "* hard nofile 524288" >> "$LIMITS_CONF"
fi

# 配置 sysctl.conf
SYSCTL_CONF="/etc/sysctl.conf"
SYSCTL_SETTINGS=(
    "fs.inotify.max_user_instances = 25535"
    "net.core.rmem_max=600000000"
    "net.core.wmem_max=600000000"
)

for setting in "${SYSCTL_SETTINGS[@]}"; do
    if ! grep -q "^${setting}" "$SYSCTL_CONF"; then
        echo "$setting" >> "$SYSCTL_CONF"
    fi
done

# 重新载入 sysctl 设置
sysctl -p

echo "系统参数优化完成"

# 创建 titanpcdn 目录
mkdir -p /root/titanpcdn
cd /root/titanpcdn || exit

# 让用户输入 KEY
read -p "请输入您的 KEY: " user_key
read -p "请输入您的网卡（多个网卡用逗号分隔，如 eth0,eth1）: " user_interfaces

# 生成 .env 文件
cat > .env <<EOF
KEY=$user_key
HOOK_ENABLE=true
HOOK_REGION=cn
HOOK_INTERFACES=$user_interfaces
EOF

# 生成 docker-compose.yml 文件
cat > docker-compose.yml <<EOF
version: "3.9"
services:
  agent:
    image: aron666/titan-agent2
    privileged: true
    restart: always
    tty: true
    stdin_open: true
    security_opt:
      - apparmor=unconfined
    network_mode: host
    volumes:
      - ./data:/app/data
      - ./data/docker:/var/lib/docker
      - ./.env:/app/agent/.env:ro
      - /etc/docker:/etc/docker:ro
EOF

# 拉取 Docker 镜像
docker compose pull

# 询问是否启动程序
read -p "是否启动程序？(y/n): " start_choice
if [[ "$start_choice" == "y" ]]; then
    docker compose up -d
    echo "Titan Agent 已启动"
else
    echo "已退出，不启动 Titan Agent"
fi