#!/bin/bash
# 脚本功能：
# 1. 检查是否以 root 身份运行
# 2. 检查是否安装 docker，没有则安装 docker（更新库后安装）
# 3. 生成 docker-compose.yml 文件，支持用户自定义存储空间大小、身份码、以及目标文件夹（默认为 /root）
# 4. 启动 docker-compose 项目，并检查容器（titan1 ~ titan5）是否全部启动成功

# 检查是否以 root 用户执行
if [ "$EUID" -ne 0 ]; then
    echo "必须以 root 身份运行此脚本"
    exit 1
fi

# 解析命令行参数，格式为 --xxx=xxx
for arg in "$@"; do
    case $arg in
        --identity=*)
            IDENTITY="${arg#*=}"
            shift
            ;;
        --storage=*)
            STORAGE="${arg#*=}"
            shift
            ;;
        --folder=*)
            FOLDER="${arg#*=}"
            shift
            ;;
        *)
            echo "未知参数: $arg"
            exit 1
            ;;
    esac
done

# 检查必须的参数是否提供
if [ -z "$IDENTITY" ] || [ -z "$STORAGE" ]; then
    echo "必须提供 --identity 和 --storage 参数，例如：--identity=EFFE4203-C6B7-463B-A648-A7878171D31C --storage=8"
    exit 1
fi

# 默认文件夹设置为 /root
if [ -z "$FOLDER" ]; then
    FOLDER="/root"
fi

# 如果指定文件夹不存在则创建
if [ ! -d "$FOLDER" ]; then
    mkdir -p "$FOLDER"
    echo "目录 $FOLDER 不存在，已自动创建"
fi

# 检查 docker 是否已安装
if ! command -v docker &> /dev/null; then
    echo "docker 未安装，正在安装 docker..."
    # 更新软件库并安装 wget（部分系统可能未安装）
    apt update && apt install -y wget
    # 下载 docker 安装脚本并执行安装，安装后删除安装脚本
    wget https://get.docker.com/ -O docker.sh && sh docker.sh && rm docker.sh
else
    echo "docker 已安装"
fi

# docker-compose 一般已随 docker 一起安装，此处不再检测

# 指定 docker-compose.yml 文件路径
DOCKER_COMPOSE_FILE="$FOLDER/docker-compose.yml"

# 生成 docker-compose.yml 文件内容
cat > "$DOCKER_COMPOSE_FILE" <<EOF
version: '3.0'
services:

  titan1: &base_config
    image: aron666/aron-titan-edge
    container_name: titan1
    environment:
      AppConfig__TITAN_NETWORK_LOCATORURL: "https://cassini-locator.titannet.io:5000/rpc/v0"
      AppConfig__TITAN_STORAGE_STORAGEGB: "$STORAGE"
      AppConfig__TITAN_STORAGE_PATH: ""
      AppConfig__TITAN_EDGE_BINDING_URL: "https://api-test1.container1.titannet.io/api/v2/device/binding"
      AppConfig__TITAN_EDGE_ID: "$IDENTITY"
      TITAN_NETWORK_LISTENADDRESS: "0.0.0.0:1234"
    restart: always
    volumes:
      - ./data/titan-01:/root/.titanedge
    ports:
      - "1234:1234"
      - "1234:1234/udp"

  titan2:
    <<: *base_config
    container_name: titan2
    environment:
      AppConfig__TITAN_NETWORK_LOCATORURL: "https://cassini-locator.titannet.io:5000/rpc/v0"
      AppConfig__TITAN_STORAGE_STORAGEGB: "$STORAGE"
      AppConfig__TITAN_STORAGE_PATH: ""
      AppConfig__TITAN_EDGE_BINDING_URL: "https://api-test1.container1.titannet.io/api/v2/device/binding"
      AppConfig__TITAN_EDGE_ID: "$IDENTITY"
      TITAN_NETWORK_LISTENADDRESS: "0.0.0.0:1234"
    volumes:
      - ./data/titan-02:/root/.titanedge
    ports:
      - "1235:1234"
      - "1235:1234/udp"

  titan3:
    <<: *base_config
    container_name: titan3
    environment:
      AppConfig__TITAN_NETWORK_LOCATORURL: "https://cassini-locator.titannet.io:5000/rpc/v0"
      AppConfig__TITAN_STORAGE_STORAGEGB: "$STORAGE"
      AppConfig__TITAN_STORAGE_PATH: ""
      AppConfig__TITAN_EDGE_BINDING_URL: "https://api-test1.container1.titannet.io/api/v2/device/binding"
      AppConfig__TITAN_EDGE_ID: "$IDENTITY"
      TITAN_NETWORK_LISTENADDRESS: "0.0.0.0:1234"
    volumes:
      - ./data/titan-03:/root/.titanedge
    ports:
      - "1236:1234"
      - "1236:1234/udp"

  titan4:
    <<: *base_config
    container_name: titan4
    environment:
      AppConfig__TITAN_NETWORK_LOCATORURL: "https://cassini-locator.titannet.io:5000/rpc/v0"
      AppConfig__TITAN_STORAGE_STORAGEGB: "$STORAGE"
      AppConfig__TITAN_STORAGE_PATH: ""
      AppConfig__TITAN_EDGE_BINDING_URL: "https://api-test1.container1.titannet.io/api/v2/device/binding"
      AppConfig__TITAN_EDGE_ID: "$IDENTITY"
      TITAN_NETWORK_LISTENADDRESS: "0.0.0.0:1234"
    volumes:
      - ./data/titan-04:/root/.titanedge
    ports:
      - "1237:1234"
      - "1237:1234/udp"

  titan5:
    <<: *base_config
    container_name: titan5
    environment:
      AppConfig__TITAN_NETWORK_LOCATORURL: "https://cassini-locator.titannet.io:5000/rpc/v0"
      AppConfig__TITAN_STORAGE_STORAGEGB: "$STORAGE"
      AppConfig__TITAN_STORAGE_PATH: ""
      AppConfig__TITAN_EDGE_BINDING_URL: "https://api-test1.container1.titannet.io/api/v2/device/binding"
      AppConfig__TITAN_EDGE_ID: "$IDENTITY"
      TITAN_NETWORK_LISTENADDRESS: "0.0.0.0:1234"
    volumes:
      - ./data/titan-05:/root/.titanedge
    ports:
      - "1238:1234"
      - "1238:1234/udp"
EOF

echo "docker-compose.yml 文件已生成在 $DOCKER_COMPOSE_FILE"

# 切换到 docker-compose.yml 所在目录并启动 docker-compose
cd "$FOLDER"
docker compose up -d

# 等待容器启动
sleep 10

# 检查 titan1~titan5 容器是否都在运行
containers=(titan1 titan2 titan3 titan4 titan5)
all_running=true
for c in "${containers[@]}"; do
    status=$(docker inspect -f '{{.State.Running}}' "$c" 2>/dev/null)
    if [ "$status" != "true" ]; then
        echo "容器 $c 启动失败"
        all_running=false
    fi
done

if [ "$all_running" = true ]; then
    echo "所有容器均已成功启动"
    exit 0
else
    echo "部分容器启动失败，请检查日志信息"
    exit 1
fi
