apt-get update
apt-get install ca-certificates curl unzip python-is-python3 open-iscsi snapd -y
systemctl enable --now iscsid

snap install amazon-ssm-agent --classic

curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
./aws/install --bin-dir /usr/local/bin --install-dir /usr/local/aws-cli 

#YQ
wget https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -O /usr/bin/yq && chmod +x /usr/bin/yq
apt-get install jq  -y