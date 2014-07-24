docker-log-central
==================

A container to fetch logs from other docker containers running on host ... and sending them away

**THIS A UNDER DEVELOPPEMENT !!! MAY NOT WORK**
**it does work-ish ...**
* **some lines are weirdly prefixed with non printable chars**
* **some logs are sent ... not in order O_o**
* **some logs are not sent**
**YUP, it need more work/coding/debugging**

Build image
-----------
`docker build -t docker-log-central` 

or just use the automated build from this repo : https://registry.hub.docker.com/u/acaranta/docker-log-central/

Run container
-------------
```
docker run -e SYSLOG_PROTO="xxx" -e SYSLOG_PORT="xxx" -e SYSLOG_HOST="xxx" \
	-v /var/run/docker.sock:/var/run/docker.sock acaranta/docker-log-central
```

* SYSLOG_PORT : the syslog port for sending logs away (default : "514" )
* SYSLOG_HOST : the syslog host for sending logs away (default : "127.0.0.1")
* SYSLOG_PROTO: the syslog protocol for sending logs away ("tcp" or "udp") (default : "tcp")

TODO
----
* Make it work cleanly/reliably
* implement the use of http Docker API (in addition to the socket endpoint)
* implement a web "tail -f" (that would be lovely)

Reference
---------
The initial code is heavily insipred from [https://github.com/stage1/aldis]
