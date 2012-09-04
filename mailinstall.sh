#!/bin/bash
#Minimal runscript, assumes not stupid.
#Intended for printing out and executing by typing/directly assigning variables.
#required variables preset: EDITOR.
#Grabbing domain information
echo -e "\nHostname (ex. mail.ccdc.local):"
read HOSTNAME2
echo -e "\nOrigin (@example.com):"
read ORIGIN
#Download
yes \ | pacman -S sudo base-devel abs python postfix dovecot spamassassin procmail vim yajl
groupadd -g 5001 spamd
useradd -u 5001 -g spamd -s /sbin/nologin -d /var/lib/spamassassin -m spamd
chown spamd:spamd /var/lib/spamassassin
#backup if you want to.
#key creation
openssl req -new -x509 -newkey rsa:1024 -days 3650 -keyout /etc/ssl/certs/mail.key -out /etc/ssl/certs/mail.crt
openssl rsa -in /etc/ssl/certs/mail.key -out /etc/ssl/certs/mail.key
mv /etc/ssl/certs/mail.key /etc/ssl/private/mail.key
#Configure postfix
echo -e "HOSTNAME2=$HOSTNAME2 \n ORIGIN=$ORIGIN" > /etc/postfix/main.cf
cat < etc.postfix.main.cf >> /etc/postfix/main.cf
#Copy confs into pace
cp etc.dovecot.dovecot.conf /etc/dovecot/dovecot.conf
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
echo -e "Users that'll be modified (already created) to gain privileges, seperated by a single space each."
read privusers
for i in $privusers; do usermod -a -G mail $i; done

#user creation mail only
echo -e "\n New users that'll be created with mail-only access seperated by a single space each"
read createusers
for i in $createusers
	do
		useradd -m -G mail -s /sbin/nologin $i
		mkdir -p /home/$i/Maildir/{.,.Drafts,.Sent,.Trash}/{cur,new,tmp}
		chmod 0700 /home/$i/Maildir/{.,.Drafts,.Sent,.Trash}/{cur,new,tmp}
		chown -R $i:$i /home/$i/*
	done

#List of Mail Users
mailline=$(cat /etc/group | grep "^mail")
groupusers=${mailline##*:}
groupusers=${groupusers/,/ }
for i in $groupusers; do echo -e "$i$ORIGIN \t $i@localhost" >> etc.postfix.virtual
##This is only if checking is required
	echo "Do you wish to check these users? [y,n]"
	read check
	test "${check,}" == y && $EDITOR etc.postfix.virtual
mv etc.postfix.virtual /etc/postfix/virtual
postmap /etc/postfix/virtual

#You can either do this next command or just add "spamd postgrey dovecot postfix" to rc.conf
daemons=$(grep DAEMON /etc/rc.conf)
sed -ie "s/${daemons}/${daemons%)*} spamd postgrey dovecot postfix )/" /etc/rc.conf

#Postgrey end
echo "$ORIGIN" >> /etc/postfix/postgrey_whitelist_recipients

#Finishing up
/usr/bin/vendor_perl/sa-update
/etc/rc.d/spamd start
/etc/rc.d/postgrey start
/etc/rc.d/dovecot start
/etc/rc.d/postfix start
