#!/bin/bash
#
#Very basic script to find and mount available NFS shares
#

#Set the address of the server
NFS_SERVER=$(curl "http://metadata.google.internal/computeMetadata/v1/project/attributes/nfs_ip" -H "Metadata-Flavor: Google")

#Install the nfs client
apt-get install -y nfs-client

#Check that the client can talk to the server
/usr/bin/timeout 2s showmount -e $NFS_SERVER --no-headers > /tmp/avail_mounts 2> /root/showmounterr.log

#Provided that the client was able to talk to the server, create mount points and add them to fstab
if [ -s /tmp/avail_mounts ]; then
	while read line; do
		dir=$(echo "$line" | sed 's/.*[^/]\/\(.*\).*\*/\1/')
		mkdir -p /mnt/$dir
		echo "$NFS_SERVER:$(echo $line | cut -d ' ' -f 1)    /mnt/$dir    nfs    defaults 0 0" >> /etc/fstab
	done < /tmp/avail_mounts
	mount -a
else
	echo "No NFS server found, or some other error. Sorry!" >> /root/showmounterr.log
fi

#Cleanup debugging file if it wasn't needed
[ -s /root/showmounterr.log ] || rm /root/showmounterr.log

#Get instance name and zone
name=$(curl -H "Metadata-Flavor:Google" http://metadata.google.internal/computeMetadata/v1/instance/name)
zone=$(curl -H "Metadata-Flavor:Google" http://metadata.google.internal/computeMetadata/v1/instance/zone)

#Remove startup script from metadata
gcloud compute instances add-metadata $name --metadata=finished=1 --zone $zone
gcloud compute instances remove-metadata $name --keys startup-script --zone $zone