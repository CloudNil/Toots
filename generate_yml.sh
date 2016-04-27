# docker-compose.yml generator
#
[ -f ./restricted/common ]    && . ./restricted/common
[ -f ./restricted/host ]      && . ./restricted/host
[ -f ./restricted/overwrite ] && . ./restricted/overwrite

MASTER=${MASTER:-"true"}
SLAVE=${SLAVE:-"true"}
EDGE=${EDGE:-"true"}

# allow to specify a specific docker image or a specific tag of the pass-in-a-box image
PANTERAS_IMAGE_TAG=${PANTERAS_IMAGE_TAG:-"latest"}
PANTERAS_DOCKER_IMAGE=${PANTERAS_DOCKER_IMAGE:-${REGISTRY}cloudnil/toots-box:${PANTERAS_IMAGE_TAG}}

#COMMON
START_CONSUL=${START_CONSUL:-"true"}
#MASTER
START_MESOS_MASTER=${START_MESOS_MASTER:-${MASTER}}
START_MARATHON=${START_MARATHON:-${MASTER}}
START_ZOOKEEPER=${START_ZOOKEEPER:-${MASTER}}
START_CHRONOS=${START_CHRONOS:-${MASTER}}
#SLAVE
START_MESOS_SLAVE=${START_MESOS_SLAVE:-${SLAVE}}
START_REGISTRATOR=${START_REGISTRATOR:-${SLAVE}}
#EDGE
START_CONSUL_TEMPLATE=${START_CONSUL_TEMPLATE:-${EDGE}}
START_FABIO=${START_FABIO:-"false"}
#OPTIONAL
START_DNSMASQ=${START_DNSMASQ:-"false"}


# Lets consul behave as a client but on slaves only
[ "${MASTER}" == "true" ] && CONSUL_MODE=${CONSUL_MODE:-'-server'}

# IP that have to be specified (cannot be 0.0.0.0)
#
HOST_IP=${HOST_IP:-${IP}}
# Consul advertise IP
CONSUL_IP=${CONSUL_IP:-${LISTEN_IP}}
CONSUL_IP=${CONSUL_IP:-${IP}}
# IP for listening
LISTEN_IP=${LISTEN_IP:-0.0.0.0}

CONSUL_DC=${CONSUL_DC:-"UNKNOWN"}
CONSUL_DOMAIN=${CONSUL_DOMAIN:-"consul"}
CONSUL_BOOTSTRAP=${CONSUL_BOOTSTRAP:-'-bootstrap-expect 1'}
CONSUL_HOSTS=${CONSUL_HOSTS:-${CONSUL_BOOTSTRAP}}
MESOS_CLUSTER_NAME=${CLUSTER_NAME:-"mesoscluster"}
MESOS_MASTER_QUORUM=${MESOS_MASTER_QUORUM:-"1"}
ZOOKEEPER_HOSTS=${ZOOKEEPER_HOSTS:-"${HOSTNAME}:2181"}
ZOOKEEPER_ID=${ZOOKEEPER_ID:-"0"}
GOMAXPROCS=${GOMAXPROCS:-"4"}
FQDN=${HOSTNAME:-"`hostname -f`"}

# Disable dnsmasq address re-mapping on non SLAVE
[ "${SLAVE}" == "false" ] && DNSMASQ_ADDRESS=${DNSMASQ_ADDRESS:-' '}
# dnsmaq cannot be set to listen on 0.0.0.0 - it causes lot of issues
# and by default it works on all addresses
DNSMASQ_ADDRESS=${DNSMASQ_ADDRESS:-"--address=/${CONSUL_DOMAIN}/${CONSUL_IP}"}
[ ${LISTEN_IP} != "0.0.0.0" ] && DNSMASQ_BIND_INTERFACES="--bind-interfaces --listen-address=${LISTEN_IP}"
# Enable HAproxy if the consul_template gets started and the mode of node is EDGE
[ "${START_CONSUL_TEMPLATE}" == "true" ] || [ "${EDGE}" == "true" ] && \
    HAPROXY_CONSUL_TEMPLATE="-template haproxy.cfg.ctmpl:/etc/haproxy/haproxy.cfg:/opt/consul-template/haproxy_reload.sh"

# enable keepalived if the consul_template(with HAproxy) gets started and a
# virtual IP address is specified
[ "${START_CONSUL_TEMPLATE}" == "true" ] && [ ${KEEPALIVED_VIP} ] && \
    KEEPALIVED_CONSUL_TEMPLATE="-template=./keepalived.conf.ctmpl:/etc/keepalived/keepalived.conf:./keepalived_reload.sh"

# Expose ports depends on which service has been mark to start
[ "${START_REGISTRATOR}" == "true" ] && {
  [ "${START_CONSUL}"        == "true" ] && PORTS="ports:" && CONSUL_UI_PORTS='- "8500:8500"'
  [ "${START_MARATHON}"      == "true" ] && PORTS="ports:" && MARATHON_PORTS='- "8080:8080"'
  [ "${START_MESOS_MASTER}"  == "true" ] && PORTS="ports:" && MESOS_PORTS='- "5050:5050"'
  [ "${START_CHRONOS}"       == "true" ] && PORTS="ports:" && CHRONOS_PORTS='- "4400:4400"'
}
# Override docker with local binary
[ "${HOST_DOCKER}" == "true" ] && VOLUME_DOCKER=${VOLUME_DOCKER:-'- "/usr/local/bin/docker:/usr/local/bin/docker"'}

# Parameters for every supervisord command
#
# -config-dir=/etc/consul.d/ \
CONSUL_PARAMS="agent \
 -client=${LISTEN_IP} \
 -advertise=${CONSUL_IP} \
 -bind=${LISTEN_IP} \
 -data-dir=/opt/consul/ \
 -ui-dir=/opt/consul/ \
 -node=${HOSTNAME} \
 -dc=${CONSUL_DC} \
 -domain ${CONSUL_DOMAIN} \
 ${CONSUL_MODE} \
 ${CONSUL_HOSTS} \
 ${CONSUL_PARAMS}"
#
CONSUL_TEMPLATE_PARAMS="-consul=${CONSUL_IP}:8500 \
 ${HAPROXY_CONSUL_TEMPLATE} \
 ${KEEPALIVED_CONSUL_TEMPLATE}"
#
DNSMASQ_PARAMS="-d \
 -u dnsmasq \
 -r /etc/resolv.conf.orig \
 -7 /etc/dnsmasq.d \
 --server=/${CONSUL_DOMAIN}/${CONSUL_IP}#8600 \
 --host-record=${HOSTNAME},${CONSUL_IP} \
 ${DNSMASQ_BIND_INTERFACES} \
 ${DNSMASQ_ADDRESS} \
 ${DNSMASQ_PARAMS}"
#
MARATHON_PARAMS="--master zk://${ZOOKEEPER_HOSTS}/mesos \
 --zk zk://${ZOOKEEPER_HOSTS}/marathon \
 --hostname ${HOSTNAME} \
 --no-logger \
 --http_address ${LISTEN_IP} \
 --https_address ${LISTEN_IP} \
 ${MARATHON_PARAMS}"
#
MESOS_MASTER_PARAMS="--zk=zk://${ZOOKEEPER_HOSTS}/mesos \
 --work_dir=/var/lib/mesos \
 --quorum=${MESOS_MASTER_QUORUM} \
 --ip=${LISTEN_IP} \
 --hostname=${FQDN} \
 --cluster=${MESOS_CLUSTER_NAME} \
 --log_dir=/var/log/Toots \
 --quiet \
 --logbufsecs=10 \
 ${MESOS_MASTER_PARAMS}"
#
MESOS_SLAVE_PARAMS="--master=zk://${ZOOKEEPER_HOSTS}/mesos \
 --containerizers=docker,mesos \
 --executor_registration_timeout=5mins \
 --hostname=${FQDN} \
 --ip=${LISTEN_IP} \
 --docker_stop_timeout=5secs \
 --gc_delay=1days \
 --docker_remove_delay=10mins \
 --docker_socket=/tmp/docker.sock \
 --launcher=posix \
 --cgroups_limit_swap \
 --log_dir=/var/log/Toots \
 --quiet \
 --logbufsecs=10 \
 ${MESOS_SLAVE_PARAMS}"
#
REGISTRATOR_PARAMS="-cleanup -ip=${HOST_IP} consul://${CONSUL_IP}:8500 \
 ${REGISTRATOR_PARAMS}"
#
ZOOKEEPER_PARAMS="start-foreground"
#
CHRONOS_PARAMS="--master zk://${ZOOKEEPER_HOSTS}/mesos \
 --zk_hosts ${ZOOKEEPER_HOSTS} \
 --http_address ${LISTEN_IP} \
 --http_port 4400 \
 --hostname ${HOSTNAME} \
 ${CHRONOS_PARAMS}"
#
FABIO_PARAMS="-cfg ./fabio.properties"

CONSUL_APP_PARAMS=${CONSUL_APP_PARAMS:-$CONSUL_PARAMS}
CONSUL_TEMPLATE_APP_PARAMS=${CONSUL_TEMPLATE_APP_PARAMS:-$CONSUL_TEMPLATE_PARAMS}
DNSMASQ_APP_PARAMS=${DNSMASQ_APP_PARAMS:-$DNSMASQ_PARAMS}
MARATHON_APP_PARAMS=${MARATHON_APP_PARAMS:-$MARATHON_PARAMS}
MESOS_MASTER_APP_PARAMS=${MESOS_MASTER_APP_PARAMS:-$MESOS_MASTER_PARAMS}
MESOS_SLAVE_APP_PARAMS=${MESOS_SLAVE_APP_PARAMS:-$MESOS_SLAVE_PARAMS}
REGISTRATOR_APP_PARAMS=${REGISTRATOR_APP_PARAMS:-$REGISTRATOR_PARAMS}
ZOOKEEPER_APP_PARAMS=${ZOOKEEPER_APP_PARAMS:-$ZOOKEEPER_PARAMS}
CHRONOS_APP_PARAMS=${CHRONOS_APP_PARAMS:-$CHRONOS_PARAMS}
FABIO_APP_PARAMS=${FABIO_APP_PARAMS:-$FABIO_PARAMS}

PANTERAS_HOSTNAME=${PANTERAS_HOSTNAME:-${HOSTNAME}}
PANTERAS_RESTART=${PANTERAS_RESTART:-"always"}

# Put your ENV varaible in ./restricted/env
mkdir -p ./restricted
touch ./restricted/env

eval "$(cat docker-compose.yml.tpl| sed 's/"/+++/g'|sed  's/^\(.*\)$/echo "\1"/')" |sed 's/+++/"/g'|sed 's;\\";";g' > docker-compose.yml
