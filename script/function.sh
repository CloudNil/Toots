#!/usr/bin/env bash
## -------------------------------------------------------------------------------------
# check root user
# --------------------------------------------------------------------------------------
# this script need root user access on target node. if you have root user id, please
# execute with 'sudo' command.
function check_root() {
	if [ $UID -ne 0 ]; then
		echo "warning: this script was designed for root user."
		exit 1
	fi
}

function check_centos() {
	os_version='centos-release-7'
	version=`rpm -q centos-release`
	if [[ ! $version == $os_version* ]]; then
		echo "Error: os version isn't centos 7."
		exit 1
	fi
}

# --------------------------------------------------------------------------------------
# package installation function
# --------------------------------------------------------------------------------------
function install_package() {
  yum install -y "$@"
}

function cover_resolve(){
  if [ ! -f "/etc/resolv.conf.orig" ];then
    if [ -d "/etc/resolv.conf.orig" ]; then
      rm -rf /etc/resolv.conf.orig
    fi
    cp /etc/resolv.conf /etc/resolv.conf.orig 
    echo "nameserver $IP" > /etc/resolv.conf
  fi
}

function recover_resolve(){
	if [ -f '/etc/resolv.conf.orig' ];then
  	cp /etc/resolv.conf.orig /etc/resolv.conf
  	rm -f /etc/resolv.conf.orig
	fi
}

function registry_config(){
	if [ -f "$CA" ]; then
    cat $CA >> /etc/pki/tls/certs/ca-bundle.crt
    rm -f $CA
    echo "$REGISTRY_IP registry.super.com" >> /etc/hosts
  else
    echo "Warning: The CA certificate $CA isn't exist!"
    echo '========Added CA certificate already?========'
    echo '1. yes'
    echo '2. no'
    echo '============================================='
    read -p 'Please enter your choice(Default:1):' option
    case "$option" in
    "1"|"" ) 
      echo 'Skipping CA certificate Configuration!'
      ;;
    "2" )
      echo "Please make sure the CA certificate file $CA is exist in the same directory with me."
      exit 1
      ;;
    * ) echo 'Error: Your choice is incorrect!' && exit 1;;
  esac
  fi
}

function capture_ip(){
	IP=`ip a|awk '/'${NIC}'$/{print $2}'`
	if [ $IP ]; then
  	IP=${IP%/*}
	else
  	echo "Error: can't get a valid IP from NIC:${NIC}"
  	exit 1
	fi
}
