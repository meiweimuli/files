#!/bin/sh

# 安装docker
if [ -z $(command -v docker) ]; then
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

cat <<EOF >docker-compose.yaml
services:
  portainer:
    image: portainer/portainer-ce:2.18.3
    container_name: portainer
    networks:
      - brinet
    ports:
      - 8000:8000
      - 9443:9443
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - data:/data
    restart: always
volumes:
  data:
networks:
  brinet:
    external: true
    name: brinet
EOF

docker network create --driver bridge brinet

docker compose down
docker compose up -d
