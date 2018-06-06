#!/bin/bash
#
#Install a basic nfs server with a few shared directories
#

#Install updates
yum update -y

#Install nfs utilities
yum install -y nfs-utils

#Make the fileshare directories
mkdir -p /var/nfsshare/devstuff /var/nfsshare/testing /var/nfsshare/home_dirs

#Open them up to the world **TESTING ONLY**
chmod -R 777 /var/nfsshare/

#Enable the nfs-server and make sure everything is started
systemctl enable nfs-server
systemctl restart nfs-server nfs-lock nfs-idmap rpcbind

#Add all subdirectories in the nfsshare directory to exports
for i in $(find /var/nfsshare/ -mindepth 1 -type d); do
	echo "$i *(rw,sync,no_all_squash)" >> /etc/exports
done

#restart the nfs server
systemctl restart nfs-server

#Get instance name and zone
name=$(curl -H "Metadata-Flavor:Google" http://metadata.google.internal/computeMetadata/v1/instance/name)
zone=$(curl -H "Metadata-Flavor:Google" http://metadata.google.internal/computeMetadata/v1/instance/zone)

#Remove startup script from metadata
gcloud compute instances add-metadata $name --metadata=finished=1 --zone $zone
gcloud compute instances remove-metadata $name --keys startup-script --zone $zone