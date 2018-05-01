#!/bin/bash
#
#Very basic script to find and mount available NFS shares
#

#Set the address of the server
NFS_SERVER=172.31.17.241

#Install the nfs client
apt-get install -y nfs-client

#Check that the client can talk to the server
/usr/bin/timeout 2s showmount -e $NFS_SERVER --no-headers > /tmp/avail_mounts 2> /root/showmounterr.log

#Provided that the client was able to talk to the server, create mount points and add them to fstab
if [ -s /tmp/avail_mounts ]; then
	while read line; do
		dir=$(echo $line | sed 's/.*[^/]\/\(.*\).*\*/\1/')
		mkdir -p /mnt/$dir
		echo "$NFS_SERVER:$(echo $line | cut -d ' ' -f 1)    /mnt/$dir    nfs    defaults 0 0" >> /etc/fstab
	done < /tmp/avail_mounts
	mount -a
else
	echo "No NFS server found, or some other error. Sorry!" >> /root/showmounterr.log
fi
