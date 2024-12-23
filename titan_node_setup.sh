#!/bin/bash

# 检测Docker是否已安装
if ! command -v docker &> /dev/null; then
    echo "Docker未安装，正在安装Docker..."
    sudo apt update
    wget https://get.docker.com/ -O docker.sh
    sudo sh docker.sh
    rm docker.sh
else
    echo "Docker已安装，跳过安装步骤。"
fi

# 检测docker-compose是否已安装
if ! command -v docker-compose &> /dev/null; then
    echo "未检测到docker-compose，正在安装..."
    sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
else
    echo "docker-compose已安装，跳过安装步骤。"
fi

# 询问用户是否来自中国大陆地区
read -p "是否为中国大陆地区服务器，是请输入y，不是请直接按回车或输入n：" region

if [ "$region" == "y" ]; then
    echo "配置Docker镜像源..."
    sudo mkdir -p /etc/docker
    echo '{
"registry-mirrors": [
    "https://docker.m.daocloud.io",
    "https://noohub.ru",
    "https://huecker.io",
    "https://dockerhub.timeweb.cloud",
    "https://docker.rainbond.cc"
]
}' | sudo tee /etc/docker/daemon.json
    sudo systemctl restart docker
else
    echo "跳过Docker镜像源配置。"
fi

# 创建titan-node目录
mkdir -p ~/titan-node
cd ~/titan-node

# 获取用户输入
read -p "请输入存储空间大小(例如: 2): " storage_size
read -p "请输入您的身份码: " identity_code
read -p "请输入数据存储路径，不改路径直接按回车(默认: ./): " storage_path
storage_path=${storage_path:-.}

# 检查并创建存储路径
if [ ! -d "$storage_path" ]; then
    echo "存储路径 $storage_path 不存在，正在创建..."
    mkdir -p "$storage_path"
fi

# 获取多实例数量
while true; do
  read -p "请输入多开数量(1-5, 默认: 1): " instance_count
  instance_count=${instance_count:-1}
  if [[ $instance_count =~ ^[1-5]$ ]]; then
    break
  else
    echo "多开数量无效，请输入1到5之间的数字。"
  fi
done

# 生成docker-compose.yml文件
cat > docker-compose.yml <<EOL
version: '3.0'
services:
  titan1: &base_config
    image: aron666/aron-titan-edge
    container_name: titan1
    environment:
      AppConfig__TITAN_NETWORK_LOCATORURL: "https://cassini-locator.titannet.io:5000/rpc/v0"
      AppConfig__TITAN_STORAGE_STORAGEGB: "${storage_size}"
      AppConfig__TITAN_STORAGE_PATH: "${storage_path}/data1"
      AppConfig__TITAN_EDGE_BINDING_URL: "https://api-test1.container1.titannet.io/api/v2/device/binding"
      AppConfig__TITAN_EDGE_ID: "${identity_code}"
    restart: always
    volumes:
      - ${storage_path}/data1:/root/.titanedge
    ports:
      - "1234:1234"
      - "1234:1234/udp"
EOL

# 追加多实例配置
for i in $(seq 2 $instance_count); do
  port_base=$((1234 + i - 1))
  # 检查端口是否被占用
  while lsof -i:$port_base &> /dev/null; do
    echo "端口 $port_base 被占用，尝试分配下一个端口..."
    port_base=$((port_base + 1))
  done

  cat >> docker-compose.yml <<EOL

  titan${i}:
    <<: *base_config
    container_name: titan${i}
    environment:
      AppConfig__TITAN_STORAGE_PATH: "${storage_path}/data${i}"
    volumes:
      - ${storage_path}/data${i}:/root/.titanedge
    ports:
      - "${port_base}:1234"
      - "${port_base}:1234/udp"
EOL
done

echo "docker-compose.yml文件已生成。"

# 启动容器并检查状态
docker-compose up -d
if [ $? -eq 0 ]; then
    echo "容器启动成功！"
    docker-compose ps
else
    echo "容器启动失败，请检查日志。"
fi
