#!/bin/bash
function docker_setup() {
	docker ps
	if [ $? -ne 0 ]; then
		docker_engine_setup
		docker_enter_setup
	else
  	systemctl restart docker
	fi
}

function docker_engine_setup() {
	tee /etc/yum.repos.d/docker.repo <<-'EOF'
[dockerrepo]
name=Docker Repository
baseurl=https://yum.dockerproject.org/repo/main/centos/$releasever/
enabled=1
gpgcheck=1
gpgkey=https://yum.dockerproject.org/gpg
EOF
  install_package docker-engine
  systemctl start docker
  systemctl enable docker.service
}

function docker_enter_setup() {
	wget -P ~ https://github.com/yeasy/docker_practice/raw/master/_local/.bashrc_docker
	echo "[ -f ~/.bashrc_docker ] && . ~/.bashrc_docker" >> ~/.bashrc
	source ~/.bashrc
}

function docker_compose_setup(){
	while [ ! -f "/usr/local/bin/docker-compose" ] || [ ! -s "/usr/local/bin/docker-compose" ]; do
  	curl -L https://github.com/docker/compose/releases/download/1.7.0/docker-compose-`uname -s`-`uname -m` > /usr/local/bin/docker-compose
  	chmod +x /usr/local/bin/docker-compose
	done
}

function docker_compose_startup(){
	cd $1 && docker-compose up -d
}

function docker_compose_clean(){
	cd $1 && docker-compose stop && docker-compose rm -f && rm -rf /tmp/mesos
}

function docker_registry_setup(){
	docker_setup
	mkdir -p ~/certs
	cd ~/certs
	openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout ca.key -out ca.crt
	cd ~

	mkdir -p auth
	docker run --entrypoint htpasswd registry:2 -Bbn admin 1 > auth/htpasswd

	docker run -d -p 443:5000 --restart=always --name registry \
	-v `pwd`/auth:/auth \
	-e "REGISTRY_AUTH=htpasswd" \
  	-e "REGISTRY_AUTH_HTPASSWD_REALM=Registry Realm" \
  	-e REGISTRY_AUTH_HTPASSWD_PATH=/auth/htpasswd \
  	-v `pwd`/certs:/certs \
  	-v /opt/data/registry:/var/lib/registry:rw \
  	-e REGISTRY_HTTP_TLS_CERTIFICATE=/certs/ca.crt \
  	-e REGISTRY_HTTP_TLS_KEY=/certs/ca.key \
  	registry:2

  	# docker run -d -p 443:5000 --restart=always --name registry \
  	# -v `pwd`/certs:/certs \
  	# -v /opt/data/registry:/var/lib/registry:rw \
  	# -e REGISTRY_HTTP_TLS_CERTIFICATE=/certs/super.crt \
  	# -e REGISTRY_HTTP_TLS_KEY=/certs/super.key \
  	# registry:2
}
