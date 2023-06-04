#!/bin/sh

ufw allow 1:65535/tcp

# 安装docker
if [ ! -$(command -v docker) ]; then
  apt-get remove docker docker-engine docker.io containerd runc
  apt-get update
  apt-get -y install ca-certificates curl gnupg
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  chmod a+r /etc/apt/keyrings/docker.gpg
  echo \
    "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
  "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" |
    tee /etc/apt/sources.list.d/docker.list >/dev/null
  apt-get update
  apt-get -y install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
fi

mkdir -p html

cat <<EOF >html/index.html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>hello</title>
</head>
<body>
<div>hello</div>
</body>
</html>
EOF

cat <<EOF >Caddyfile
mars.mykuon.xyz
{
  log {
	  output file /var/log/caddy/access.log
  }
  reverse_proxy /F5EW0ueeFZ h2c://v2fly:23500 {
    header_up Host {host}
    header_up X-Real-IP {remote}
    header_up X-Forwarded-For {remote}
    header_up X-Forwarded-Port {server_port}
    header_up X-Forwarded-Proto "https"
  }

  @v2ray_websocket {
    path /VR20tyGNis
    header Connection Upgrade
    header Upgrade websocket
  }
  reverse_proxy @v2ray_websocket  v2fly:21400

  reverse_proxy /v1/chat/completions  https://api.openai.com {
    header_up Host api.openai.com
  }

  reverse_proxy /fb* filebrowser:80

  file_server browse {
	  root          /var/share/caddy/
	  index         index.html
  }

}
EOF

cat <<EOF >v2fly.json
{
  "log": {
    "access": "/var/log/v2ray/access.log",
    "error": "/var/log/v2ray/error.log"
  },
  "inbounds": [
    {
      "port": "23500",
      "listen": "127.0.0.1",
      "protocol": "vmess",
      "settings": {
        "clients": [
          {
            "id": "6b6f5969-0381-432a-939c-4ab6bc8c2350",
            "alterId": 0
          }
        ]
      },
      "streamSettings": {
        "network": "http",
        "httpSettings": {
          "path": "/F5EW0ueeFZ",
          "host": [
            "mars.mykuon.xyz"
          ]
        }
      }
    },
    {
      "port": "21400",
      "listen": "127.0.0.1",
      "protocol": "vmess",
      "settings": {
        "clients": [
          {
            "id": "6b6f5969-0381-432a-939c-4ab6bc8c2350",
            "alterId": 0
          }
        ]
      },
      "streamSettings": {
        "network": "ws",
        "wsSettings": {
          "path": "/VR20tyGNis"
        }
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "settings": {
        "domainStrategy": "UseIPv4"
      }
    }
  ]
}
EOF

cat <<EOF >docker-compose.yaml
services:
  portainer:
    image: portainer/agent
    ports:
      - 9001:9001
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - /var/lib/docker/volumes:/var/lib/docker/volumes
    restart: always
  filebrowser:
    image: filebrowser/filebrowser
    networks:
      - v2net
    volumes:
      - /:/srv
    environment:
      - FB_BASEURL=/fb
    restart: always
  caddy:
    image: caddy
    networks:
      - v2net
    ports:
      - 443:443
      - 80:80
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile
      - ./html:/var/share/caddy/
    restart: always
  v2fly:
    image: v2fly/v2fly-core
    networks:
      - v2net
    volumes:
      - ./v2fly.json:/etc/v2fly/config.json
    restart: always

networks:
  v2net:
    driver: bridge
EOF

docker compose down
docker compose up -d
