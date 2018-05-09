#!/bin/bash
#
#Install a basic nfs server with a few shared directories
#

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
