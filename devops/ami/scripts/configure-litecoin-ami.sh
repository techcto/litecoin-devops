tee /root/init-litecoin.sh <<'EOF'
#!/bin/bash
EC2_INSTANCE_ID="`wget -q -O - http://169.254.169.254/latest/meta-data/instance-id || die \"wget instance-id has failed: $?\"`"
test -n "$EC2_INSTANCE_ID" || die 'cannot obtain instance-id'
EC2_AVAIL_ZONE="`wget -q -O - http://169.254.169.254/latest/meta-data/placement/availability-zone || die \"wget availability-zone has failed: $?\"`"
test -n "$EC2_AVAIL_ZONE" || die 'cannot obtain availability-zone'
EC2_REGION="\`echo "$EC2_AVAIL_ZONE" | sed -e 's:\([0-9][0-9]*\)[a-z]*\$:\\1:'\`"

wget https://raw.githubusercontent.com/bitcoin/bitcoin/master/share/rpcauth/rpcauth.py && chmod +x rpcauth.py
PASSWORD=$(./rpcauth.py litecoin)

sed -i -e "s/{{RPC_PASS}}/$PASSWORD/g" /etc/litecoin/litecoin.conf

rm -f /root/init-litecoin.sh
EOF

chmod 700 /root/init-litecoin.sh
tee /etc/cloud/cloud.cfg.d/install.cfg <<'EOF'
#install-config
runcmd:
- /root/init-litecoin.sh
EOF