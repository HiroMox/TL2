#!/bin/bash

# 检测Docker是否安装
if ! [ -x "$(command -v docker)" ]; then
  echo "Docker未安装，正在安装Docker..."
  sudo apt update
  wget https://get.docker.com/ -O docker.sh
  sudo sh docker.sh
  rm docker.sh
else
  echo "Docker已安装"
fi

# 检测Docker Compose是否安装
if ! [ -x "$(command -v docker-compose)" ]; then
  echo "Docker Compose未安装，正在安装Docker Compose..."
  sudo apt install docker-compose -y
else
  echo "Docker Compose已安装"
fi

# 创建titan-node目录
mkdir -p ~/titan-node
cd ~/titan-node

# 获取用户输入
read -p "请输入存储空间大小(例如: 2g): " storage_size
read -p "请输入您的身份码: " identity_code
read -p "请输入数据存储路径(默认: ./): " storage_path
storage_path=${storage_path:-.}

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
      AppConfig__TITAN_STORAGE_PATH: ""
      AppConfig__TITAN_EDGE_BINDING_URL: "https://api-test1.container1.titannet.io/api/v2/device/binding"
      AppConfig__TITAN_EDGE_ID: "${identity_code}"
    restart: always
    volumes:
      - ${storage_path}/data:/root/.titanedge
    ports:
      - "1234:1234"
      - "1234:1234/udp"
EOL

for i in $(seq 2 $instance_count); do
  port_base=$((1234 + i - 1))
  cat >> docker-compose.yml <<EOL

  titan${i}:
    <<: *base_config
    container_name: titan${i}
    volumes:
      - ${storage_path}/data${i}:/root/.titanedge
    ports:
      - "${port_base}:1234"
      - "${port_base}:1234/udp"
EOL
done

echo "docker-compose.yml文件已生成。"

# 启动Docker服务
docker-compose up -d