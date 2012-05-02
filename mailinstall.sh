#!/bin/bash
DIRCOR="$( cd -P "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
CURWD=`pwd`
if [ ! "$DIRCOR" = "$CURWD" ]; then 
		echo -e "\nPlease execute from the directory directly"
		exit 1 
fi


echo -e "\nPlease configure pacman before starting this. Also, your network needs to be connected. Have you done this? [Y/N]"
read  KILL
if [[ ! "$KILL" = *[yY] ]]; then
		exit 1
fi
#Preferences
echo -e "\nWhat is your preferred text editor? I prefer vim, but if you'd like to use nano, you can. Defaults to vim."
read $EDITOR
if [ -z "$EDITOR" ]; then
	EDITOR=vim
fi
echo -e "\nYour Editor will be $EDITOR"

#Grabbing domain information
echo -e "\nHostname (ex. mail.ccdc.local):"
read HOSTNAME2
echo -e "\nOrigin (@example.com):"
read ORIGIN


#Install
echo -e "\nDownloading Neccessary Files"
yes \ | pacman -S sudo base-devel abs python postfix dovecot spamassassin procmail vim yajl
groupadd -g 5001 spamd
useradd -u 5001 -g spamd -s /sbin/nologin -d /var/lib/spamassassin -m spamd
chown spamd:spamd /var/lib/spamassassin

#backup
echo -e "\nBacking Up Configuration Files"
mv /etc/dovecot/dovecot.conf /etc/dovecot/dovecot.conf.backup 
mv /etc/conf.d/spamd /etc/conf.d/spamd.backup
mv /etc/postfix/main.cf /etc/postfix/main.cf.backup
mv /etc/postfix/master.cf /etc/postfix/master.cf.backup
mv /etc/mail/spamassassin/local.cf /etc/mail/spamassassin/local.cf.backup
mv /etc/procmailrc /etc/procmailrc.backup

#creating keys
echo -e "\nCreating Keys"
openssl req -new -x509 -newkey rsa:1024 -days 3650 -keyout /etc/ssl/certs/mail.key -out /etc/ssl/certs/mail.crt
openssl rsa -in /etc/ssl/certs/mail.key -out /etc/ssl/certs/mail.key
mv /etc/ssl/certs/mail.key /etc/ssl/private/mail.key


#making postfix correct
echo -e "\nConfiguring Postfix"
sed -e s/HOSTNAMEYES/"$HOSTNAME2"/g etc.postfix.main.cf > etc.postfix.main.cf.halfway
sed -e s/ORIGINYES/"$ORIGIN"/g etc.postfix.main.cf.halfway > etc.postfix.main.cf.almost
sed -e s/VIRTUALALIASDOMAINS/"$ORIGIN"/g etc.postfix.main.cf.almost > etc.postfix.main.cf.configured
cp etc.postfix.main.cf.configured /etc/postfix/main.cf

#copying
echo -e "\nCopying configuration files"
cp ./etc.dovecot.dovecot.conf /etc/dovecot/dovecot.conf
cp etc.conf.d.spamd /etc/conf.d/spamd
cp etc.postfix.master.cf /etc/postfix/master.cf
cp etc.mail.spamassassin.local.cf /etc/mail/spamassassin/local.cf
cp etc.procmailrc /etc/procmailrc

#Yaourt

wget http://aur.archlinux.org/packages/yaourt/yaourt.tar.gz
wget http://aur.archlinux.org/packages/pa/package-query/package-query.tar.gz
chmod 077 *.tar.gz
tar -xzvf yaourt.tar.gz 
tar -xzvf package-query.tar.gz
yes | `makepkg -p package-query/PKGBUILD -i --asroot`
yes | `makepkg -p yaourt/PKGBUILD -i --asroot`
yaourt --noconfirm -S postgrey




#User Modding
echo -e "\nUsers to be modified to gain mail priviliges seperated by commas (no spaces)"
read MODIFYINGUSERS
echo $MODIFYINGUSERS > modifyusers.txt
sed -i 's/,/\n/g' modifyusers.txt
for i in `cat modifyingusers.txt`
	do
		usermod -a -G mail $i
	done

#User Creating
echo -e "\nUsernames to be created seperated by commas (no spaces)"
read CREATINGUSERS
echo $CREATINGUSERS > startusers.txt
sed -i 's/,/\n/g' startusers.txt 
for i in `cat startusers.txt`
	do
		useradd -m -G mail -s /sbin/nologin $i
	done
for i in `cat startusers.txt` 
	do
		mkdir -p /home/$i/Maildir/{.,.Drafts,.Sent,.Trash}/{cur,new,tmp}
	done
for i in `cat startusers.txt` 
	do
		chmod 0700 /home/$i/Maildir/{.,.Drafts,.Sent,.Trash}/{cur,new,tmp}
	done
for i in `cat startusers.txt`
	do
		chown -R $i:$i /home/$i/*
	done

#List of Mail Users
cat /etc/group | grep "^mail" > group.txt

sed -i "s/mail:x:..://g" group.txt
sed -i 's/,/\n/g' group.txt


#Postfix Final Configuration
cp etc.postfix.virtual etc.postfix.virtual.started
for i in `cat group.txt`
	do
		echo "$i@$ORIGIN	$i@localhost" >> etc.postfix.virtual.started
	done
read -p "Press enter to begin editing /etc/postfix/virutal in vim"
cp etc.postfix.virtual.started etc.postfix.virtual.editing
vim etc.postfix.virtual.editing
mv etc.postfix.virtual.editing /etc/postfix/virtual
postmap /etc/postfix/virtual
read -p "Now you're gonna edit rc.conf. modify DAEMONS=( ....) on the bottom and add "spamd postgrey dovecot postfix" inside the parenthesis"
vim /etc/rc.conf
echo "$ORIGIN" >> /etc/postfix/postgrey_whitelist_recipients

#Finishing up
/usr/bin/vendor_perl/sa-update
/etc/rc.d/spamd start
/etc/rc.d/postgrey start
/etc/rc.d/dovecot start
/etc/rc.d/postfix start
