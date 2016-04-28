## Architecture

### Components
- Mesos + Marathon + ZooKeeper + Chronos (orchestration components)
- Consul (K/V store, monitoring, service directory and registry)  + Registrator (automating register/ deregister)
- HAproxy + consul-template (load balancer with dynamic config generation)

##### Combination of daemons startup
|    Component    | Master | Slave | Edge |
| --------------- | ------ | ----- | ---- |
| Mesos-master    |   √    |   ×   |   ×  |
| Mesos-slave     |   ×    |   √   |   ×  |
| Marathon        |   √    |   ×   |   ×  |
| Zookeeper       |   √    |   ×   |   ×  |
| Consul          |   √    |   √   |   √  |
| Consul-template |   ×    |   ○   |   √  |
| Haproxy         |   ×    |   ○   |   √  |
| Registrator     |   ○    |   √   |   ×  |
| dnsmasq         |   ×    |   ○   |   ×  |
| Chronos         |   √    |   ×   |   ×  |

## Requirements:
- docker >= 1.10
- docker-compose >= 1.5.1

## Usage:
Clone it
```
git clone https://github.com/CloudNil/Toots.git
cd Toots
```
#### Config 
Before run the deploy tools,please check the config file `Toots.conf`
```
#Master Hosts (At least 3 Master Node)
MASTERS=<MasterIP_1>,<MasterIP_2>,<MasterIP_3>...

#Network Interface Card (Like 'eth0')
NIC=<NIC>

##########Optional configuration###########
# Internal Domain for private DNS and LB(Only for Slave node)
# By default is "consul"
# IN_DOMAIN=cloudnil.com

# External Domain Name(Only for Edge node)
# EX_DOMAIN=cloudnil.com

# VIP(Only for Edge node)
# VIP=50.50.0.102

# NFS Server IP(Only for Persistent Slave node)
# NFS=192.168.2.91:/store

# Private Docker Registry
# By default is official registry
# REGISTRY_IP=192.168.2.91
# CA=super.crt
```
Replace the `<MasterIP_1>,<MasterIP_2>,<MasterIP_3>` and `<NIC>` with yours.
##### Start Up:
```
./Toots.sh
```
There are some options need you to choose,such as:
```
========Install Mode========
1. Master
2. Master + Slave
3. Master + Slave + Edge
============================
```
or
```
========Install Mode========
1. Slave
2. Edge
3. Slave + Edge
============================
```
and so on,please read explanation above it.

## Web Interfaces

You can reach the PaaS components
on the following ports:

- HAproxy: http://hostname:81
- Consul: http://hostname:8500
- Chronos: http://hostname:4400
- Marathon: http://hostname:8080
- Mesos: http://hostname:5050
- Supervisord: http://hostname:9000

## Put service into HAproxy HTTP load-balancer

In order to put a service `my_service` into the `HTTP` load-balancer (`HAproxy`), you need to add a `consul` tag `haproxy` 
(ENV `"SERVICE_TAGS" : "haproxy"`) to the JSON deployment plan for `my_service` (see examples). `my_service` is then accessible
on port `80` via `my_service.service.consul:80` and/or `my_service.service.<my_dc>.consul:80`.

Anothers tag `route_domain` or `route_path` is used for accessing your service like blew,but `route_domain` fits `<SERVICE_NAME>.cloudnil.com` and `route_path` fits `cloudnil.com/<PATH_ROOT>`.

If you provide an additional environment variable `HAPROXY_ADD_DOMAIN` during the configuration phase you can access the
service with that domain appended to the service name as well, e.g., with `HAPROXY_ADD_DOMAIN="cloudnil.com"` you
can access the service ((ENV `"SERVICE_NAME" : "python"`)) `<SERVICE_NAME>` via `<SERVICE_NAME>.cloudnil.com` (if the IP address returned by a DNS query for
`*.cloudnil.com` is pointing to one of the nodes `Edge`).

A example env configuration is:
```
"SERVICE_TAGS" : "haproxy,route_domain,weight=1",
"SERVICE_NAME" : "python"
```

## Put service into HAproxy TCP load-balancer

In order to put a service `my_service` into the `TCP` load-balancer (`HAproxy`), you need to add a `consul` tag `haproxy_tcp` specifying
the specific `<port>` (ENV `SERVICE_TAGS="haproxy_tcp=<port>"`) to the JSON deployment plan for `my_service`. It is also recommended
to set the same `<port>` as the `servicePort` in the `docker` part of the JSON deployment plan. `my_service` is then accessible on
the specific `<port>` on all cluster nodes, e.g., `my_service.service.consul:<port>` and/or `my_service.service.<my_dc>.consul:<port>`.

## Create A/B test services (AKA canaries services)

1. You need to create services with the same consul name (ENV `SERVICE_NAME="consul_service"`), but different marathon `id` in every JSON deployment plan (see examples)
2. You need to set different [weights](http://cbonte.github.io/haproxy-dconv/configuration-1.5.html#weight) for those services. You can propagate weight value using consul tag  
(ENV `SERVICE_TAGS="haproxy,weight=1"`)
3. We set the default weight value for `100` (max is `256`).

