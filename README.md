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
Replace the `<MasterIP_1>,<MasterIP_2>,<MasterIP_3>` and <NIC> with yours.
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

## Listening address

All PaaS components listen default on all interfaces (to all addresses: `0.0.0.0`),  
which might be dangerous if you want to expose the PaaS.  
Use ENV `LISTEN_IP` if you want to listen on specific IP address.  
for example:  
`echo LISTEN_IP=192.168.10.10 >> restricted/host`  
This might not work for all services like Marathon or Chronos that has some additional random ports.

## Services Accessibility

You might want to access the PaaS and services
with your browser directly via service name like:

http://your_service.service.consul

This could be problematic. It depends where you run docker host.
We have prepared two services that might help you solving this problem.

DNS - which supposed to be running on every docker host,
it is important that you have only one DNS server occupying port 53 on docker host,
you might need to disable yours, if you have already configured.

If you have direct access to the docker host DNS,
then just modify your /etc/resolv.conf adding its IP address.

If you do NOT have direct access to docker host DNS,
then you have two options:

A. use OpenVPN client
an example server we have created for you (in optional),
but you need to provide certificates and config file,
it might be little bit complex for the beginners,
so you might to try second option first.

B. SSHuttle - use https://github.com/apenwarr/sshuttle project so you can tunnel DNS traffic over ssh
but you have to have ssh daemon running in some container.

## Running an example application

There are two examples available:  
`SimpleWebappPython` - basic example - spawn 2x2 containers  
`SmoothWebappPython` - similar to previous one, but with smooth scaling down  

HAproxy will balance the ports which where mapped and assigned by marathon. 

For non human access like services intercommunication, you can use direct access 
using DNS consul SRV abilities, to verify answers:

```
$ dig python.service.consul +tcp SRV
```

or ask consul DNS directly:

```
$ dig @$CONSUL_IP -p8600  python.service.consul +tcp SRV
```

Remember to disable DNS caching in your future services.

## Put service into HAproxy HTTP load-balancer

In order to put a service `my_service` into the `HTTP` load-balancer (`HAproxy`), you need to add a `consul` tag `haproxy` 
(ENV `SERVICE_TAGS="haproxy"`) to the JSON deployment plan for `my_service` (see examples). `my_service` is then accessible
on port `80` via `my_service.service.consul:80` and/or `my_service.service.<my_dc>.consul:80`.

If you provide an additional environment variable `HAPROXY_ADD_DOMAIN` during the configuration phase you can access the
service with that domain appended to the service name as well, e.g., with `HAPROXY_ADD_DOMAIN=".my.own.domain.com"` you
can access the service `my_service` via `my_service.my.own.domain.com:80` (if the IP address returned by a DNS query for
`*.my.own.domain.com` is pointing to one of the nodes running an `HAProxy` instance).

You can also provide the additional `consul` tag `haproxy_route` with a corresponding value in order to dispatch the
service based on the beginning of the `URL`; e.g., if you add the additional tag `haproxy_route=/minions` to the service
definition for service `gru`, all `HTTP` requests against any of the cluster nodes on port `80` starting with `/minions/`
will be re-routed to and load-balanced for the service `gru` (e.g., `http://cluster_node.my_company.com/minions/say/banana`).
Note that no `URL` rewrite happens, so the service gets the full `URL` (`/minions/say/banana`) passed in.

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

## Deploy using marathon_deploy

You can deploy your services using `marathon_deploy`, which also understand YAML and JSON files.
As a benefit, you can have static part in YAML deployment plans, and dynamic part (like version or URL)
set with `ENV` variables, specified with `%%MACROS%%` in deployment plan.

```apt-get install ruby1.9.1-dev```  
```gem install marathon_deploy```  

more info: https://github.com/eBayClassifiedsGroup/marathon_deploy


## References

[1] https://www.docker.com/  
[2] http://docs.docker.com/compose/  
[3] http://stackoverflow.com/questions/25217208/setting-up-a-docker-fig-mesos-environment  
[4] http://www.consul.io/docs/  

