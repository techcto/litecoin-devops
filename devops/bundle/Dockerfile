FROM ubuntu:22.04

ARG SHARE
ENV SHARE=${SHARE}
ARG SOLODEV_RELEASE
ENV SOLODEV_RELEASE=${SOLODEV_RELEASE}

RUN apt update
RUN apt-get install -y zip

COPY ./submodules/litecoin/. /litecoin
WORKDIR /litecoin

RUN echo $SOLODEV_RELEASE > version.txt && ls -al
RUN zip -r litecoin.zip .
RUN ls -al

#Entrypoint
COPY devops/bundle/bundle.sh /bundle.sh
RUN chmod a+rx /bundle.sh

ENTRYPOINT ["sh", "/bundle.sh"]