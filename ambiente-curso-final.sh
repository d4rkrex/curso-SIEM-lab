#!/bin/bash

function WazuhInstall()
{
mkdir -p /opt/wazuh-compose && cd /opt/wazuh-compose
chmod 777 /opt/wazuh-compose
curl -so docker-compose.yml https://raw.githubusercontent.com/wazuh/wazuh-docker/v3.13.1_7.8.0/docker-compose.yml
sed -i -e 's/"80:80"/"9080:80"/' docker-compose.yml
sed -i -e 's/"443:443"/"1443:443"/' docker-compose.yml
docker-compose up -d 
}

function banner3()
{
  echo "+---------------------------------------------+"
  printf "`tput bold` %-40s `tput sgr0`\n" "$@"
  echo "+---------------------------------------------+"
}

#### Logstash y Filebeat
function beatsInstall()
{

curl -s https://artifacts.elastic.co/GPG-KEY-elasticsearch | apt-key add -
echo "deb https://artifacts.elastic.co/packages/7.x/apt stable main" | tee /etc/apt/sources.list.d/elastic-7.x.list
apt-get update && apt-get install filebeat logstash

}

function icingaInstall()
{
git clone https://github.com/jjethwa/icinga2.git /opt/icinga2
chmod 777 /opt/icinga2
cd /opt/icinga2
echo "MYSQL_ROOT_PASSWORD=<password>" > secrets_sql.env
docker-compose up
}

function preInstall()
{
apt update && apt upgrade -y
apt-get install -y  curl apt-transport-https ca-certificates software-properties-common curl apt-transport-https
apt-get install -y openjdk-8-jre
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
sudo apt update && apt install -y docker-ce
apt-get install -y docker-compose
}


function configureBeats()
{
cat <<'EOF' > /etc/filebeat/filebeat.yml
filebeat.inputs:
- type: log
  enabled: true
  paths:
    - /opt/icinga2/data/icinga/log/icinga2/*log
  fields_under_root: true
  fields:
    program: icinga2
  multiline.pattern: '^\['
  multiline.negate: true
  multiline.match: after

output.logstash:
  enabled: true
  hosts: ["localhost:5044",]
  compression_level: 3  
EOF
echo -e '- pipeline.id: icinga\n  path.config: "/etc/logstash/conf.d/icinga/*conf"' >> /etc/logstash/pipelines.yml
git clone https://github.com/Icinga/icinga-logstash-pipeline.git /etc/logstash/conf.d/icinga
ls /etc/logstash/conf.d/icinga |grep -v conf |while read line; do rm -fr  "/etc/logstash/conf.d/icinga/$line";done;
cat <<'EOF' > /etc/logstash/conf.d/icinga/input.conf
input {
  beats {
    port => 5044
  }
}
EOF

cat <<'EOF' > /etc/logstash/conf.d/icinga/output.conf
output {
  elasticsearch {
    hosts => ["http://localhost:9200"]
  }
}
EOF

}

#

### Main ####
preInstall
WazuhInstall
IncingaInstall
beatsInstall
configureBeats

service filebeat restart  
service logstash restart  
IP1=$(curl ifconfig.me)
banner3 "Ambiente instalado  conectese a $IP1/icingaweb2"
banner3 "USUARIO icingaadmin" "CONTRASEÑA: icinga"

