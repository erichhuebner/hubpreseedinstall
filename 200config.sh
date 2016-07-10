#! /bin/bash
mkdir -p -m 775 /var/log/installer/hubzero/
touch /var/log/installer/hubzero/install_log

#fix dnshostname ----------------------------------------------------------------------

#get current IP
curip=$(ip addr | grep 'state UP' -A2 | tail -n1 | awk '{print $2}' | cut -f1  -d'/')

#get current doomain pointer for this host
curdns=$(host $curip | awk '{print $NF}' | sed s/.$//)
curdnshostname=$(echo $curdns | sed s/............$//)

fristdomainname=$(echo $curdns | cut -d. -f1)
seconddomainname=$(echo $curdns | cut -d. -f2)

sed -i "s/127.0.1.1.*/127.0.1.1       $curdns       $curdnshostname/" /etc/hosts
echo $curdns > /etc/hostname

/etc/init.d/hostname.sh | tee -a /var/log/installer/hubzero/install_log
#/etc/init.d/networking stop | tee -a /var/log/installer/hubzero/install_log

#/etc/init.d/networking start | tee -a /var/log/installer/hubzero/install_log

#dhclient -v eth0 | tee -a /var/log/installer/hubzero/install_log
#----------------------------
#domainname=$(dnsdomainname) | tee -a /var/log/installer/hubzero/install_log'
#echo "Hostname is $HOSTNAME" | tee -a /var/log/installer/hubzero/install_log'
#echo "Domainname is $domainname" | tee -a /var/log/installer/hubzero/install_log'
#thisfqdn=$HOSTNAME.$domainname | tee -a /var/log/installer/hubzero/install_log'
#echo "FQDN is $thisfqdn" | tee -a /var/log/installer/hubzero/install_log'

#echo $HOSTNAME > /etc/hostname | tee -a /var/log/installer/hubzero/install_log'
#sed -i "1s/.*/127.0.1.1       example.com       example/" /etc/hosts | tee -a /var/log/installer/hubzero/install_log'

#/etc/init.d/hostname.sh | tee -a /var/log/installer/hubzero/install_log'
#/etc/init.d/networking stop | tee -a /var/log/installer/hubzero/install_log'
#/etc/init.d/networking start | tee -a /var/log/installer/hubzero/install_log'

#dhclient -v -r eth0 | tee -a /var/log/installer/hubzero/install_log'
#dhclient -v eth0 | tee -a /var/log/installer/hubzero/install_log'

#sed -i "1d" /etc/hosts | tee -a /var/log/installer/hubzero/install_log'
#-------------------------------------------------------------------------------------

#Remove cdrom from apt sources
sed -i "/\b\(cdrom\)\b/d" /etc/apt/sources.list | tee -a /var/log/installer/hubzero/install_log

echo "-- END log created; sources.list, /etc/hosts updated ------------------------------------" | tee -a /var/log/installer/hubzero/install_log


##Exim
echo "-- BEGIN Exim install ------------------------------------" | tee -a /var/log/installer/hubzero/install_log
debconf-set-selections <<< "exim4-config exim4/dc_eximconfig_configtype select internet site; mail is sent and received directly using SMTP"
debconf-set-selections <<< "exim4-config exim4/mailname	string $curdns" 
debconf-set-selections <<< "exim4-config exim4/dc_local_interfaces string"
debconf-set-selections <<< "exim4-config exim4/dc_other_hostnames string"
debconf-set-selections <<< "exim4-config exim4/dc_relay_domains string"
debconf-set-selections <<< "exim4-config exim4/dc_relay_nets string"
debconf-set-selections <<< "exim4-config exim4/dc_minimaldns boolean false"
debconf-set-selections <<< "exim4-config exim4/dc_localdelivery select mbox format in /var/mail/"
debconf-set-selections <<< "exim4-config exim4/use_split_config boolean true"

apt-get install -y exim4 | tee -a /var/log/installer/hubzero/install_log
echo "-- END Exim install ------------------------------------" | tee -a /var/log/installer/hubzero/install_log


##CMS
echo "-- BEGIN CMS install ------------------------------------" | tee -a /var/log/installer/hubzero/install_log
apt-get install -y hubzero-cms-2.0.0 | tee -a /var/log/installer/hubzero/install_log
echo "-- CMS config ------------------------------------" | tee -a /var/log/installer/hubzero/install_log
hzcms install example | tee -a /var/log/installer/hubzero/install_log
hzcms update | tee -a /var/log/installer/hubzero/install_log
a2dissite default default-ssl | tee -a /var/log/installer/hubzero/install_log
a2ensite example example-ssl | tee -a /var/log/installer/hubzero/install_log
/etc/init.d/apache2 restart | tee -a /var/log/installer/hubzero/install_log
echo "-- END CMS install ------------------------------------" | tee -a /var/log/installer/hubzero/install_log


##LDAP
echo "-- BEGIN LDAP install ------------------------------------" | tee -a /var/log/installer/hubzero/install_log
ldapranpass=$(date +%s | sha256sum | base64 | head -c 16)
echo "LDAP passwrod $ldapranpass" | tee -a /var/log/installer/hubzero/install_log

debconf-set-selections <<< "slapd slapd/internal/generated_adminpw password $ldapranpass"
debconf-set-selections <<< "slapd slapd/password2 password $ldapranpass"
debconf-set-selections <<< "slapd slapd/internal/adminpw password $ldapranpass"
debconf-set-selections <<< "slapd slapd/password1 password $ldapranpass"
debconf-set-selections <<< "nslcd nslcd/ldap-bindpw password $ldapranpas"
debconf-set-selections <<< "slapd slapd/allow_ldap_v2 boolean false"
debconf-set-selections <<< "nslcd nslcd/ldap-starttls boolean false"
debconf-set-selections <<< "nslcd nslcd/ldap-base string dc=$fristdomainname,dc=$seconddomainname"
debconf-set-selections <<< "nslcd nslcd/ldap-auth-type select none"
debconf-set-selections <<< "libnss-ldapd libnss-ldapd/nsswitch multiselect group, passwd, shadow"
debconf-set-selections <<< "nslcd nslcd/ldap-uris	string ldap://localhost/"

apt-get install -y hubzero-openldap | tee -a /var/log/installer/hubzero/install_log

echo "-- LDAP config ------------------------------------" | tee -a /var/log/installer/hubzero/install_log
hzldap init | tee -a /var/log/installer/hubzero/install_log
hzcms configure ldap --enable | tee -a /var/log/installer/hubzero/install_log
hzldap syncusers | tee -a /var/log/installer/hubzero/install_log
echo "-- END LDAP install ------------------------------------" | tee -a /var/log/installer/hubzero/install_log


##Webdav
echo "-- BEGIN Webdav install ------------------------------------" | tee -a /var/log/installer/hubzero/install_log
apt-get install -y hubzero-webdav | tee -a /var/log/installer/hubzero/install_log
echo "-- Webdav config ------------------------------------" | tee -a /var/log/installer/hubzero/install_log
hzcms configure webdav --enable | tee -a /var/log/installer/hubzero/install_log
echo "-- END Webdav install ------------------------------------" | tee -a /var/log/installer/hubzero/install_log


##Subversion
echo "-- BEGIN Subversion install ------------------------------------" | tee -a /var/log/installer/hubzero/install_log
apt-get install -y hubzero-subversion | tee -a /var/log/installer/hubzero/install_log
echo "-- Subversion config ------------------------------------" | tee -a /var/log/installer/hubzero/install_log
hzcms configure subversion --enable | tee -a /var/log/installer/hubzero/install_log
echo "-- END Subversion install ------------------------------------" | tee -a /var/log/installer/hubzero/install_log


##TRAC
echo "-- BEGIN trac install ------------------------------------" | tee -a /var/log/installer/hubzero/install_log
apt-get install -y hubzero-trac | tee -a /var/log/installer/hubzero/install_log
echo "-- TRAC config ------------------------------------" | tee -a /var/log/installer/hubzero/install_log
hzcms configure trac --enable | tee -a /var/log/installer/hubzero/install_log
echo "-- END TRAC install ------------------------------------" | tee -a /var/log/installer/hubzero/install_log


##Forge
echo "-- BEGIN Forge install ------------------------------------" | tee -a /var/log/installer/hubzero/install_log
apt-get install -y hubzero-forge | tee -a /var/log/installer/hubzero/install_log
echo "-- Forge config ------------------------------------" | tee -a /var/log/installer/hubzero/install_log
hzcms configure forge --enable | tee -a /var/log/installer/hubzero/install_log
echo "-- END Forge install ------------------------------------" | tee -a /var/log/installer/hubzero/install_log


##OpenVZ
echo "-- BEGIN OpenVZ config ------------------------------------" | tee -a /var/log/installer/hubzero/install_log
hzcms configure openvz --enable | tee -a /var/log/installer/hubzero/install_log
echo "-- END OpenVZ config ------------------------------------" | tee -a /var/log/installer/hubzero/install_log


##Maxwell Service
echo "-- BEGIN Maxwell Service install ------------------------------------" | tee -a /var/log/installer/hubzero/install_log
apt-get install -y hubzero-mw-service | tee -a /var/log/installer/hubzero/install_log
echo "-- Maxwell Service config ------------------------------------" | tee -a /var/log/installer/hubzero/install_log
mkvztemplate amd64 wheezy ellie | tee -a /var/log/installer/hubzero/install_log
hzcms configure mw-service --enable | tee -a /var/log/installer/hubzero/install_log
echo "-- END Maxwell Service install ------------------------------------" | tee -a /var/log/installer/hubzero/install_log


##Maxwell Client
echo "-- BEGIN Maxwell Client install ------------------------------------" | tee -a /var/log/installer/hubzero/install_log
apt-get install -y hubzero-mw-client | tee -a /var/log/installer/hubzero/install_log
echo "-- Maxwell Client config ------------------------------------" | tee -a /var/log/installer/hubzero/install_log
hzcms configure mw-client --enable | tee -a /var/log/installer/hubzero/install_log
echo "-- END Maxwell Client install ------------------------------------" | tee -a /var/log/installer/hubzero/install_log


##Vncproxy
echo "-- BEGIN Vncproxy install ------------------------------------" | tee -a /var/log/installer/hubzero/install_log
apt-get install -y hubzero-vncproxy | tee -a /var/log/installer/hubzero/install_log
echo "-- Vncproxy config ------------------------------------" | tee -a /var/log/installer/hubzero/install_log
hzcms configure vncproxy --enable | tee -a /var/log/installer/hubzero/install_log
echo "-- END Vncproxy install ------------------------------------" | tee -a /var/log/installer/hubzero/install_log


##Telequotad
echo "-- BEGIN Telequotad install ------------------------------------" | tee -a /var/log/installer/hubzero/install_log
apt-get install -y hubzero-telequotad | tee -a /var/log/installer/hubzero/install_log
echo "-- Telequotad config ------------------------------------" | tee -a /var/log/installer/hubzero/install_log
sed -i "s/errors=remount-ro/quota,&/" /etc/fstab | tee -a /var/log/installer/hubzero/install_log
mount -oremount / | tee -a /var/log/installer/hubzero/install_log
/etc/init.d/quota restart | tee -a /var/log/installer/hubzero/install_log
hzcms configure telequotad --enable | tee -a /var/log/installer/hubzero/install_log
echo "-- END Telequotad install ------------------------------------" | tee -a /var/log/installer/hubzero/install_log


##Workspace
echo "-- BEGIN Workspace install ------------------------------------" | tee -a /var/log/installer/hubzero/install_log
apt-get install -y hubzero-app | tee -a /var/log/installer/hubzero/install_log
apt-get install -y hubzero-app-workspace | tee -a /var/log/installer/hubzero/install_log
echo "-- Workspace config ------------------------------------" | tee -a /var/log/installer/hubzero/install_log
hubzero-app install --publish /usr/share/hubzero/apps/workspace-1.3.hza | tee -a /var/log/installer/hubzero/install_log
echo "-- END Workspace install ------------------------------------" | tee -a /var/log/installer/hubzero/install_log


##Metrics
echo "-- BEGIN Metrics install ------------------------------------" | tee -a /var/log/installer/hubzero/install_log
apt-get install -y hubzero-metrics | tee -a /var/log/installer/hubzero/install_log
echo "-- Metrics config ------------------------------------" | tee -a /var/log/installer/hubzero/install_log
hzcms configure metrics --enable | tee -a /var/log/installer/hubzero/install_log
echo "-- END Metrics install ------------------------------------" | tee -a /var/log/installer/hubzero/install_log


#Rappture
echo "-- BEGIN Rappture install ------------------------------------" | tee -a /var/log/installer/hubzero/install_log
apt-get install -y hubzero-rappture | tee -a /var/log/installer/hubzero/install_log
echo "-- Rappture config ------------------------------------" | tee -a /var/log/installer/hubzero/install_log
chroot /var/lib/vz/template/debian-7.0-amd64-maxwell bash -c 'apt-get update; apt-get upgrade -f -y --force-yes; apt-get install -y hubzero-rappture-session; exit' | tee -a /var/log/installer/hubzero/install_log
#apt-get update | tee -a /var/log/installer/hubzero/install_log
#apt-get upgrade -f -y --force-yes | tee -a /var/log/installer/hubzero/install_log
#apt-get install -y hubzero-rappture-session | tee -a /var/log/installer/hubzero/install_log
#exit | tee -a /var/log/installer/hubzero/install_log
echo "-- END Rappture install ------------------------------------" | tee -a /var/log/installer/hubzero/install_log


##Filexfer
echo "-- BEGIN Filexfer install ------------------------------------" | tee -a /var/log/installer/hubzero/install_log
apt-get install -y hubzero-filexfer-xlate | tee -a /var/log/installer/hubzero/install_log
echo "-- Filexfer config ------------------------------------" | tee -a /var/log/installer/hubzero/install_log
hzcms configure filexfer --enable | tee -a /var/log/installer/hubzero/install_log
echo "-- END Filexfer install ------------------------------------" | tee -a /var/log/installer/hubzero/install_log


##Firewall
echo "-- BEGIN Firewall install ------------------------------------" | tee -a /var/log/installer/hubzero/install_log
apt-get install -y hubzero-firewall | tee -a /var/log/installer/hubzero/install_log
echo "-- END Firewall install ------------------------------------" | tee -a /var/log/installer/hubzero/install_log


##Submit
echo "-- BEGIN Submit install ------------------------------------" | tee -a /var/log/installer/hubzero/install_log
apt-get install -y hubzero-submit-pegasus | tee -a /var/log/installer/hubzero/submit_install_log
apt-get install -y hubzero-submit-condor | tee -a /var/log/installer/hubzero/submit_install_log
apt-get install -y hubzero-submit-common | tee -a /var/log/installer/hubzero/submit_install_log
apt-get install -y hubzero-submit-server | tee -a /var/log/installer/hubzero/submit_install_log
apt-get install -y hubzero-submit-distributor | tee -a /var/log/installer/hubzero/submit_install_log
apt-get install -y hubzero-submit-monitors | tee -a /var/log/installer/hubzero/submit_install_log
echo "-- Submit config ------------------------------------" | tee -a /var/log/installer/hubzero/submit_install_log
hzcms configure submit-server --enable | tee -a /var/log/installer/hubzero/submit_install_log
/etc/init.d/submit-server start | tee -a /var/log/installer/hubzero/submit_install_log
echo "-- END Submit install ------------------------------------" | tee -a /var/log/installer/hubzero/submit_install_log


##apt-get update, upgrade
echo "-- BEGIN apt-get update and upgrade ------------------------------------" | tee -a /var/log/installer/hubzero/install_log
apt-get update | tee -a /var/log/installer/hubzero/install_log
apt-get upgrade -f -y --force-yes | tee -a /var/log/installer/hubzero/install_log
echo "-- END apt-get update and upgrade ------------------------------------" | tee -a /var/log/installer/hubzero/install_log

echo "-- Your Hub is now ready! Rebooting...------------------------------------" | tee -a /var/log/installer/hubzero/install_log

sed -i "s/GRUB_DEFAULT=0/GRUB_DEFAULT=2/" /etc/default/grub ; update-grub

reboot