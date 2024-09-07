echo "Install Litecoin"
unzip /tmp/Litecoin.zip -d /tmp/Litecoin
rm -Rf /tmp/Litecoin.zip
ls -al /tmp/Litecoin

rm -Rf /litecoin
mv /tmp/Litecoin /litecoin
cd /litecoin
chmod -Rf 2770 /litecoin
ls -al /litecoin

DEBIAN_FRONTEND=noninteractive
TZ=America/New_York

adduser litecoin
usermod -aG sudo litecoin
echo "PasswordAuthentication no" >> /etc/ssh/sshd_config
mkdir /etc/litecoin && sudo chown -R litecoin:litecoin /etc/litecoin

#Install Litecoin
apt update
apt-get install -y build-essential libtool autotools-dev automake pkg-config bsdmainutils python3 libssl-dev libdb-dev libdb++-dev libsqlite3-dev
apt-get install -y libevent-dev libboost-system-dev libboost-filesystem-dev libboost-test-dev libboost-thread-dev libfmt-dev
#BerkleyDB for wallet support
apt-get install -y libqt5gui5 libqt5core5a libqt5dbus5 qttools5-dev qttools5-dev-tools
#upnp
apt-get install -y libminiupnpc-dev
#ZMQ
apt-get install -y libzmq3-dev
#build litecoin source
./autogen.sh
./configure --with-incompatible-bdb
make
make install

#Install Service
cp -f /tmp/litecoin.conf /etc/litecoin/litecoin.conf
cp -f /tmp/litecoind.service /etc/systemd/system/litecoind.service
systemctl enable litecoind