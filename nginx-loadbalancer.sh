#!/bin/bash

yum install nginx wget -y

mkdir -p /var/lbdemo/static/

ips=$(gcloud compute instances list | grep -e '^lb-.*' | awk '{print $4}')

for i in $ips; do
   printf "    server $i:3990;\n"
done > /tmp/lbs

cat << EOF >> /etc/nginx/conf.d/lbdemo.conf
upstream django {
$(cat /tmp/lbs)
}

server {
    listen 80 default_server;
    charset utf-8;

    client_max_body_size 75M;

    location /static {
        alias /var/lbdemo/static/;
    }

    location / {
        uwsgi_pass django;
        include /etc/nginx/uwsgi_params;
    }
}
EOF

sed -i '37,$d' /etc/nginx/nginx.conf
echo '}' >> /etc/nginx/nginx.conf

wget -O /var/lbdemo/static/beach.jpg https://s3-us-west-2.amazonaws.com/robertrussell/NTI-320/wood-sea-nature-449627.jpg

systemctl enable nginx
systemctl restart nginx

#Get instance name and zone
name=$(curl -H "Metadata-Flavor:Google" http://metadata.google.internal/computeMetadata/v1/instance/name)
zone=$(curl -H "Metadata-Flavor:Google" http://metadata.google.internal/computeMetadata/v1/instance/zone)

#Remove startup script from metadata
gcloud compute instances add-metadata $name --metadata=finished=1 --zone $zone
gcloud compute instances remove-metadata $name --keys startup-script --zone $zone