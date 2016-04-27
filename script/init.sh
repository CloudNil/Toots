#!/bin/bash
function init() {
	yum update -y
	yum upgrade -y

	sed -i 's/^SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
	setenforce 0
	systemctl stop firewalld.service
	systemctl disable firewalld.service
	install_package wget curl
}
