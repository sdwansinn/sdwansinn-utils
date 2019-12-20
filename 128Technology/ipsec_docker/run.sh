#!/bin/sh
#
# Docker script to configure and start an IPsec VPN server
#
# Copyright (C) 2019 zoyo.red
# env file contain's the following parameter
# 
# VPN_IKE_VER=
# VPN_CONN=
# VPN_LEFT_ID=
# VPN_LEFT_NET=
# VPN_RIGHT=
# VPN_RIGHT_ID=
# VPN_RIGHT_NET=
# VPN_PFS=
# VPN_IKE=
# VPN_IKE_LT=
# VPN_PHASE2=
# VPN_SA_LT=
# VPN_IPSEC_PSK= 
# VPN_NAT=OC_Address_value:Customer_Address_Value OC_Address_value:Customer_Address_Value OC_Address_value:Customer_Address_Value
# 

export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

exiterr() { echo "Error: $1" >&2; exit 1; }

check_ip() {
  IP_REGEX="^(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])$"
  printf %s "$1" | tr -d '\n' | grep -Eq "$IP_REGEX"
}

if [ ! -f "/.dockerenv" ]; then
  exiterr "This script ONLY runs in a Docker container."
fi

mkdir -p /opt/ipsec/plugins
vpn_env="/opt/ipsec/plugins/vpn-gen.env"

if [ -z "$VPN_IPSEC_PSK" ]; then
  if [ -f "$vpn_env" ]; then
    echo
    echo "Retrieving previously generated VPN credentials..."
    . "$vpn_env"
  else
    echo
    echo "VPN credentials not set by user. Generating random PSK and password..."
    VPN_IPSEC_PSK="$(LC_CTYPE=C tr -dc 'A-HJ-NPR-Za-km-z2-9' < /dev/urandom | head -c 32)"
    echo "VPN_IPSEC_PSK=$VPN_IPSEC_PSK" > "$vpn_env"
    VPN_IKE_VER="1"
    echo "$VPN_IKE_VER" >> "$vpn_env"
    chmod 600 "$vpn_env"
  fi
fi


if [ -z "$VPN_IPSEC_PSK" ] && [ -z "$VPN_IKE_VER" ] && [ -z "$VPN_CONN" ] && [ -z "$VPN_LEFT_NET"] && [ -z "$VPN_RIGHT"] && [ -z "$VPN_RIGHT_NET"] && [ -z "$VPN_PFS"] && [ -z "$VPN_IKE"] && [ -z "$VPN_IKE_LT"] && [ -z "$VPN_PHASE2"] && [ -z "$VPN_SA_LT"] && [ -z "$VPN_IPSEC_PSK"]; then
  exiterr "All VPN env Parameter must be specified. Edit your 'env' file and re-enter them."
fi

if [ "$VPN_IKE_VER" -gt "2" ]; then
   exiterr "VPN_IKE_VER has invalid value"
fi


#case "$VPN_IPSEC_PSK" in
#  *[\\\"\']*)
#    exiterr "VPN credentials must not contain any of these characters: \\ \" '"
#    ;;
#esac

echo
echo 'Trying to auto discover IP of this server...'

# In case auto IP discovery fails, manually define the public IP
# of this server in your 'env' file, as variable 'VPN_PUBLIC_IP'.
PUBLIC_IP=${VPN_PUBLIC_IP:-''}

# Try to auto discover IP of this server
[ -z "$PUBLIC_IP" ] && PUBLIC_IP=$(dig @resolver1.opendns.com -t A -4 myip.opendns.com +short)

# Check IP for correct format
check_ip "$PUBLIC_IP" || PUBLIC_IP=$(wget -t 3 -T 15 -qO- http://ipv4.icanhazip.com)
check_ip "$PUBLIC_IP" || exiterr "Cannot find valid public IP. Define it in your 'env' file as 'VPN_PUBLIC_IP'."

DNS_SRV1=${VPN_DNS_SRV1:-'8.8.8.8'}
DNS_SRV2=${VPN_DNS_SRV2:-'8.8.4.4'}

# Create IPsec (Libreswan) config
if [ "$VPN_IKE_VER"  -eq "1" ]; then

cat > /etc/ipsec.conf <<EOF
version 2.0
config setup
  virtual_private=%v4:10.0.0.0/8,%v4:192.168.0.0/16,%v4:172.16.0.0/12,%v4:100.100.0.0/16
  protostack=netkey
  nhelpers=0
  uniqueids=no
conn private
  type=tunnel
  left=%defaultroute
    leftid=$VPN_LEFT_ID
    leftsubnets=$VPN_LEFT_NET
    auto=start
  right=$VPN_RIGHT
     rightid=$VPN_RIGHT
     rightsubnets=$VPN_RIGHT_NET
  authby=secret
  pfs=$VPN_PFS
  ike=$VPN_IKE
  ikelifetime=$VPN_IKE_LT
  phase2alg=$VPN_PHASE2
  salifetime=$VPN_SA_LT
EOF

echo $VPN_LEFT_NET >> /etc/ipsec.d/policies/private
echo $VPN_RIGHT_NET >> /etc/ipsec.d/policies/private
sed 's/,/\n/g' /etc/ipsec.d/policies/private


else

cat > /etc/ipsec.conf <<EOF
version 2.0
config setup
  virtual_private=%v4:10.0.0.0/8,%v4:192.168.0.0/16,%v4:172.16.0.0/12,%v4:100.100.0.0/16
  protostack=netkey
  nhelpers=0
  uniqueids=no
conn private
  type=tunnel
  left=%defaultroute
    leftid=$VPN_LEFT_ID
    leftsubnets=$VPN_LEFT_NET
    auto=start
  right=$VPN_RIGHT
     rightid=$VPN_RIGHT
     rightsubnets=$VPN_RIGHT_NET
  authby=secret
  pfs=$VPN_PFS
  ike=$VPN_IKE
  ikelifetime=$VPN_IKE_LT
  phase2alg=$VPN_PHASE2
  salifetime=$VPN_SA_LT
  dpdaction=$VPN_DPD_ACTION
  dpddelay=$VPN_DPD_DELAY
  dpdtimeout=$VPN_DPD_TIMEOUT
  forceencaps=$VPN_FORCEENCAPS
  keyingtries=$VPN_KEYINGTRIES
  ikev2=yes
EOF

echo $VPN_LEFT_NET >> /etc/ipsec.d/policies/private
echo $VPN_RIGHT_NET >> /etc/ipsec.d/policies/private
sed 's/,/\n/g' /etc/ipsec.d/policies/private

fi

# Specify IPsec PSK
cat > /etc/ipsec.secrets <<EOF
%any  $VPN_RIGHT : PSK "$VPN_IPSEC_PSK"
EOF



# Update sysctl settings
SYST='/sbin/sysctl -e -q -w'
$SYST kernel.msgmnb=65536
$SYST kernel.msgmax=65536
$SYST kernel.shmmax=68719476736
$SYST kernel.shmall=4294967296
$SYST net.ipv4.ip_forward=1
$SYST net.ipv4.tcp_syncookies=1
$SYST net.ipv4.conf.all.accept_source_route=0
$SYST net.ipv4.conf.default.accept_source_route=0
$SYST net.ipv4.conf.all.accept_redirects=0
$SYST net.ipv4.conf.default.accept_redirects=0
$SYST net.ipv4.conf.all.send_redirects=0
$SYST net.ipv4.conf.default.send_redirects=0
$SYST net.ipv4.conf.lo.send_redirects=0
$SYST net.ipv4.conf.eth0.send_redirects=0
$SYST net.ipv4.conf.all.rp_filter=0
$SYST net.ipv4.conf.default.rp_filter=0
$SYST net.ipv4.conf.lo.rp_filter=0
$SYST net.ipv4.conf.eth0.rp_filter=0
$SYST net.ipv4.icmp_echo_ignore_broadcasts=1
$SYST net.ipv4.icmp_ignore_bogus_error_responses=1
$SYST net.core.wmem_max=12582912
$SYST net.core.rmem_max=12582912
$SYST net.ipv4.tcp_rmem="10240 87380 12582912"
$SYST net.ipv4.tcp_wmem="10240 87380 12582912"

# Update file attributes
chmod 600 /etc/ipsec.secrets

cat <<EOF
================================================
Service: dockerOCipsec_v1

IPsec VPN server is now ready for use!
Connect to your new VPN with these details:
Connection Name: $VPN_CONN
Server IP: $PUBLIC_IP
IPsec PSK: $VPN_IPSEC_PSK
Write these down. You'll need them to connect!
================================================
EOF

# Load IPsec NETKEY kernel module
modprobe af_key

echo
cat /etc/ipsec.conf
echo "###############################################################"
echo
cat /etc/ipsec.d/policies/private
echo "###############################################################"

echo "###############################################################"
echo
echo "initialising nss database, this will take up to 20 sec" 
sleep 5
/usr/libexec/ipsec/_stackmanager start
/usr/sbin/ipsec --checknss
sleep 10
/usr/sbin/ipsec --checknflog > /dev/null

echo "###############################################################"
echo
echo "configuring iptable rules"
# Create IPTables rules
iptables -P FORWARD DROP
iptables -F FORWARD
iptables -t nat -F
# hier kannt evtl a dees entsprechende source und destination netzwerk eini z.B. -s 100.101.0.128/25 -d $VPN_DNAT_D
iptables -I FORWARD 1 -j ACCEPT

# Read and insert NAT Values to Array
read -a VPN_DNAT <<<$VPN_NAT

if [ ! -z "${VPN_DNAT[*]}" ]; then
   count=0
   for i in ${VPN_DNAT[@]}; do
      VPN_DNAT_D=$(echo ${VPN_DNAT[$count]} | cut -f1 -d:)
      VPN_DNAT_2D=$(echo ${VPN_DNAT[$count]} | cut -f2 -d:)
      iptables -t nat -A PREROUTING -i eth+ -d $VPN_DNAT_D -j DNAT --to-destination $VPN_DNAT_2D
      count=$((count+1))
   done
fi

echo "###############################################################"
echo
echo "run iptables -t nat -nvL"
iptables -t nat -nvL
echo "###############################################################"
echo
echo "run iptables -nvL"
iptables -nvL
echo "###############################################################"

echo "run pluto as nofork" 
/usr/libexec/ipsec/pluto --config /etc/ipsec.conf --nofork
echo
echo "run.sh done ..."
echo "The following command will helps..."
echo "docker exec CONT_ID ipsec whack  --trafficstatus"
echo "docker exec CONT_ID ipsec status"
echo "docker exec CONT_ID ip -s xfrm state"
echo "docker exec CONT_ID ip -s xfrm policy"
echo "###############################################################"

