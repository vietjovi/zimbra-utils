#!/bin/bash

# Author: vietovi@gmail.com

# REF: https://wiki.zimbra.com/wiki/Installing_a_LetsEncrypt_SSL_Certificate
### HOW TO USE
## Run The Script with Root Privileges
## You also need to download the ISRG Root X1 then place it where you will run the script
# wget https://letsencrypt.org/certs/isrgrootx1.pem.txt

### Automatically Renew LetsEncrypt Certificate. Create a crontab like below to run the script every 2 months
# 0 2 1 */2 * /root/letsencrypt_script/update_cert.sh >> /root/letsencrypt_script/log.txt 2>&1 

# Stop Zimbra Proxy
su - zimbra -c "zmproxyctl stop"
# su - zimbra -c "zmmailboxdctl stop"

# Variables
EMAIL="admin@yourdomain.com" 
DOMAIN="mail.yourdomain.com"
echo $EMAIL 
echo $DOMAIN

certbot certonly --standalone \
  -d $DOMAIN \
  --preferred-challenges http \
  --agree-tos \
  -n \
  -m $EMAIL \
  --keep-until-expiring \
  --preferred-chain "ISRG Root X1" \

# Backup
cp -va /opt/zimbra/ssl/zimbra /root/letsencrypt_script/backup/zimbra.$(date "+%Y%.m%.d-%H.%M")

mkdir /opt/zimbra/ssl/letsencrypt
rm -vf /opt/zimbra/ssl/letsencrypt/*
cp -v /etc/letsencrypt/live/$DOMAIN/* /opt/zimbra/ssl/letsencrypt
ls /opt/zimbra/ssl/letsencrypt/
cat /etc/letsencrypt/live/$DOMAIN/chain.pem | tee /opt/zimbra/ssl/letsencrypt/zimbra_chain.pem
cat /root/letsencrypt_script/isrgrootx1.pem.txt >> /opt/zimbra/ssl/letsencrypt/zimbra_chain.pem
chown -R zimbra:zimbra /opt/zimbra/ssl/

# Verify
su - zimbra -c '/opt/zimbra/bin/zmcertmgr verifycrt comm /opt/zimbra/ssl/letsencrypt/privkey.pem /opt/zimbra/ssl/letsencrypt/cert.pem /opt/zimbra/ssl/letsencrypt/zimbra_chain.pem'

# Update private key
rm -vf /opt/zimbra/ssl/zimbra/commercial/commercial.key
cp -v /opt/zimbra/ssl/letsencrypt/privkey.pem /opt/zimbra/ssl/zimbra/commercial/commercial.key
chown zimbra:zimbra /opt/zimbra/ssl/zimbra/commercial/commercial.key
chown -R zimbra:zimbra /opt/zimbra/ssl/

# Deploy the new Let’s Encrypt SSL certificate.
su - zimbra -c '/opt/zimbra/bin/zmcertmgr deploycrt comm /opt/zimbra/ssl/letsencrypt/cert.pem /opt/zimbra/ssl/letsencrypt/zimbra_chain.pem'

# Restart zimbra services
sudo su - zimbra -c "zmcontrol restart"
