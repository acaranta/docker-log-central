FROM ubuntu:trusty

MAINTAINER Arthur Caranta <arthur@caranta.com>

RUN apt-get update -y
RUN apt-get install -y nodejs nodejs-legacy curl
RUN curl https://www.npmjs.org/install.sh | clean=no sh
RUN npm install -g coffee-script

ADD docker-log-central.coffee /dockerlogcentral/docker-log-central.coffee
ADD package.json /dockerlogcentral/package.json

WORKDIR /dockerlogcentral
RUN npm install

#ENTRYPOINT ["/usr/bin/coffee", "/dockerlogcentral/docker-log-central.coffee"]
CMD /usr/bin/coffee /dockerlogcentral/docker-log-central.coffee
