docker-log-central
==================

A container to fetch logs from other docker containers running on host ... and sending them away

**THIS A UNDER DEVELOPPEMENT !!! MAY NOT WORK**

Build image
-----------
`docker build -t docker-log-central` 

Run container
-------------
`docker run -v /var/run/docker.sock:/var/run/docker.sock docker-log-central`

Reference
---------
The initial code is heavily insipred from [https://github.com/stage1/aldis]
