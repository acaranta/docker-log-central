docker-log-central
==================

A container to fetch logs from other docker containers running on host ... and sending them away

**THIS A UNDER DEVELOPPEMENT !!! MAY NOT WORK**

Build image
-----------
`docker build -t docker-log-central` 

Run container
-------------
`docker run -e OUT_PORT="xxx" -e OUT_HOST="xxx" -v /var/run/docker.sock:/var/run/docker.sock docker-log-central`

* OUT_PORT : the tcp port for sending logs away
* OUT_HOST : the tcp host for sending logs away

currently in dev, the log shipping is only json sent via a TCP connection.

Reference
---------
The initial code is heavily insipred from [https://github.com/stage1/aldis]
