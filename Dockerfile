FROM ubuntu:22.04
COPY ./litecoin.conf /root/.litecoin/litecoin.conf
COPY . /litecoin
WORKDIR /litecoin
#shared libraries and dependencies

ARG DEBIAN_FRONTEND=noninteractive
ENV TZ=America/New_York

RUN apt update
RUN apt-get install -y build-essential libtool autotools-dev automake pkg-config bsdmainutils python3 libssl-dev libdb-dev libdb++-dev
RUN apt-get install -y libevent-dev libboost-system-dev libboost-filesystem-dev libboost-test-dev libboost-thread-dev libfmt-dev
#BerkleyDB for wallet support
RUN apt-get install -y libqt5gui5 libqt5core5a libqt5dbus5 qttools5-dev qttools5-dev-tools
#upnp
RUN apt-get install -y libminiupnpc-dev
#ZMQ
RUN apt-get install -y libzmq3-dev
#build litecoin source
RUN ./autogen.sh
RUN ./configure --with-incompatible-bdb
RUN make
RUN make install
#open service port
EXPOSE 9666 19666
CMD ["litecoind", "--printtoconsole"]