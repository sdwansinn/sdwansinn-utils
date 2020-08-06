
#!/bin/bash
#
#  Copyright 2019 <zoyo.red@sandsturm.com>
#
#  This program is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 3 of the License, or
#  (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this program; if not, write to the Free Software
#  Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
#  MA 02110-1301, USA.
#

# set var
exiterr() { echo -e "Error: $1" >&2; exit 1; }

PATH=/opt/a1/bin:$PATH
CHECK_MARK="\033[0;32m\xE2\x9C\x94\033[0m"
SRCDIR="/etc/letsencrypt/archive/vco1-fra.a1.digital"
DSTDIR="/etc/nginx/velocloud/ssl/vco1-fra.a1.digital"
GUEST="root@192.168.122.249"


#
echo "flush iptables"
iptables -F -t nat
#
echo "start local nginx service"
systemctl start nginx
#
echo "start request to renew certificates"
certbot renew -i nginx
#
echo "restart iptables and close all unused ports"
systemctl restart iptables
#
echo "stop local nginx service"
systemctl stop nginx
#
echo "get last certificate file number and copy certificates to guest"
NUM=$(ls -t ${SRCDIR} |head -1 |grep -o '[0-9]*')
scp ${SRCDIR}/privkey${NUM}.pem ${GUEST}:${DSTDIR}/privkey.pem
scp ${SRCDIR}/fullchain${NUM}.pem ${GUEST}:${DSTDIR}/fullchain.pem
scp ${SRCDIR}/cert${NUM}.pem ${GUEST}:${DSTDIR}/cert.pem
scp ${SRCDIR}/chain${NUM}.pem ${GUEST}:${DSTDIR}/chain.pem
#
echo "restart nginx service on guest"
ssh ${GUEST} service nginx restart
#
echo "start validation of new certificates"
# check jq installed
JQCLIENT=$(which jq)
[[ ! -x ${JQCLIENT} ]] && { exiterr "Please install jq first! To install latest version use your OS paket manager"; }
# check ssllabs installed
SSLLABSSCAN=$(which ssllabs-scan)
[[ ! -x ${SSLLABSSCAN} ]] && { exiterr "Please install ssllabs-scan firts! Download from https://github.com/ssllabs/ssllabs-scan/releases/download/v1.4.0/ssllabs-scan_1.4.0-linux64.tgz and unpack in a valid bin path"; }

RESULT=$(ssllabs-scan -hostcheck vco1-fra.a1.digital |jq)
NOTAFTER=$(echo ${RESULT} |jq '.[] .endpoints[].details.cert.notAfter')
SUBJECT=$(echo ${RESULT} |jq '.[] .endpoints[].details.cert.subject')
HASWARNINGS=$(echo ${RESULT} |jq '.[] .endpoints[].hasWarnings')
ISEXCEPTIONAL=$(echo ${RESULT} |jq '.[] .endpoints[].isExceptional')
MINAFTER=$(date -d "5 days" +%s)

if [[ ${HASWARNINGS} == 'false' ]]; then
  [[ ${NOTAFTER} -le ${MINAFTER} ]] && { echo "Validation Date of certificates is too low"; echo ${RESULT} > /var/log/cert.log}
  if [[ ${ISEXCEPTIONAL} == 'true' ]]; then
    echo "Validation of ${SUBJECT} looks fine"
  else
    echo "Certificate is not exceptional. Please check /var/log/cert.log"
    echo ${RESULT} > /var/log/cert.log
  fi
else
  echo "Validation of certificates contains warning. Please check /var/log/cert.log"
  echo ${RESULT} > /var/log/cert.log
fi

