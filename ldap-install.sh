#!/bin/bash

#Automating LDAP server install for NTI-310


#Install git and clone the instructional repo
yum install -y git

git clone https://github.com/nic-instruction/hello-nti-310/ /tmp/


#Intall the ldap packages
yum install -y openldap-servers openldap-clients

cp /usr/share/openldap-servers/DB_CONFIG.example /var/lib/ldap/DB_CONFIG

chown ldap. /var/lib/ldap/DB_CONFIG

systemctl enable slapd
systemctl start slapd

yum install -y epel-release
yum install -y httpd phpldapadmin

setsebool -P httpd_can_connect_ldap on

systemctl enable httpd
systemctl start httpd

sed -i 's,Require local,#Require local\n    Require all granted,g' /etc/httpd/conf.d/phpldapadmin.conf

cp /tmp/hello-nti-310/config/config.php /etc/phpldpadmin/config.php
chown ldap:apache /etc/phpldapadmin/config.php  

systemctl restart httpd

echo "phpldapadmin is now up and running"
echo "configuring ldap and ldapadmin"

#Generate new password and hash it.

newsecret=$(slappasswd -g)
newhash=$(slappasswd -s "$newsecret")
echo -n "$newsecret" > /root/ldap_admin_pass
chmod 0600 /root/ldap_admin_pass

#Create the basic configuration for the ldap server, setting the domain

echo "dn: olcDatabase={2}hdb,cn=config
changetype: modify
replace: olcSuffix
olcSuffix: dc=nti310,dc=local

dn: olcDatabase={2}hdb,cn=config
changetype: modify
replace: olcRootDN
olcRootDN: cn=ldapadm,dc=nti310,dc=local

dn: olcDatabase={2}hdb,cn=config
changetype: modify
replace: olcRootPW
olcRootPW: $newhash" >> /tmp/db.ldif

ldapmodify -Y EXTERNAL -H ldapi:/// -f /tmp/db.ldif

#Restrict auth

echo 'dn: olcDatabase={1}monitor,cn=config
changetype: modify
replace: olcAccess
olcAccess: {0}to * by dn.base="gidNumber=0+uidNumber=0,cn=peercred,cn=external, cn=auth" read by dn.base="cn=ldapadm,dc=nti310,dc=local" read by * none' > /tmp/monitor.ldif

ldapmodify -Y EXTERNAL  -H ldapi:/// -f /tmp/monitor.ldif

#Generate cert file for eventual ldaps

openssl req -new -x509 -nodes -out /etc/openldap/certs/nti310ldapcert.pem -keyout /etc/openldap/certs/nti310ldapkey.pem -days 365 -subj "/C=US/ST=WA/L=Seattle/O=SCC/OU=IT/CN=nti310.local"

chown -R ldap. "/etc/opeldap/certs/nti*.pem"

#Use Certs in LDAP

echo "dn: cn=config
changetype: modify
replace: olcTLSCertificateFile
olcTLSCertificateFile: /etc/openldap/certs/nti310ldapcert.pem

dn: cn=config
changetype: modify
replace: olcTLSCertificateKeyFile
olcTLSCertificateKeyFile: /etc/openldap/certs/nti310ldapkey.pem" > /tmp/certs.ldif

ldapadd -Y EXTERNAL -H ldapi:/// -f /tmp/certs.ldif

#Test the certs

slaptest -u

unalias cp

#Copy example config to actual config

cp /usr/share/openldap-servers/DB_CONFIG.example /var/lib/ldap/DB_CONFIG
chown ldap. /var/lib/ldap/*

ldapadd -Y EXTERNAL -H ldapi:/// -f /etc/openldap/schema/cosine.ldif
ldapadd -Y EXTERNAL -H ldapi:/// -f /etc/openldap/schema/nis.ldif
ldapadd -Y EXTERNAL -H ldapi:/// -f /etc/openldap/schema/inetorgperson.ldif

#Create basic structure

echo "dn: dc=nti310,dc=local
dc: nti310
objectClass: top
objectClass: domain

dn: cn=ldapadm ,dc=nti310,dc=local
objectClass: organizationalRole
cn: ldapadm
description: LDAP Manager

dn: ou=People,dc=nti310,dc=local
objectClass: organizationalUnit
ou: People

dn: ou=Group,dc=nti310,dc=local
objectClass: organizationalUnit
ou: Group" > /tmp/base.ldif

#Add the basic structure just created to the LDAP database.
ldapdd -x -W -D "cn=ldapadm,dc=nti310,dc=local" -f base.ldif -y /root/ldap_admin_pass
