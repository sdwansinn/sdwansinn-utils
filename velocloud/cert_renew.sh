
#!/bin/bash
iptables -F -t nat
systemctl start nginx
certbot renew -i nginx
systemctl restart iptables
systemctl stop nginx
genisoimage -output /var/lib/libvirt/images/letsencrypt.iso -volid cidata -joliet -rock /etc/letsencrypt/archive/vco1-fra.a1.digital/*.pem /etc/letsencrypt/ssl-dhparams.pem
echo "Mount ISO on VCO and copy files manually to VCO's cert directory"
ssh local.vco1-fra "mount /dev/cdrom /media/cdrom; $NUM=`ls -t /media/cdrom |head -1 |grep -o '[0-9]*'`; cp /media/cdrom/privkey$NUM.pem /etc/nginx/velocloud/ssl/vco1-fra.a1.digital/privkey.pem; cp /media/cdrom/fullchain$NUM.pem /etc/nginx/velocloud/ssl/vco1-fra.a1.digital/fullchain.pem; cp /media/cdrom/cert$NUM.pem  /etc/nginx/velocloud/ssl/vco1-fra.a1.digital/cert.pem; cp /media/cdrom/chain$NUM.pem /etc/nginx/velocloud/ssl/vco1-fra.a1.digital/chain.pem; service nginx restart; umount /media/cdrom"
echo "done - please run: openssl s_client -showcerts -connect vco1-fra-a1.digital:443"
