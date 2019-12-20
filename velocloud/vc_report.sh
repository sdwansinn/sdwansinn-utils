#!/bin/bash
#
#  Copyright 2019 <zoyo.red@sandsturm.com> and bUN93
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
CHECK_MARK="\033[0;32m\xE2\x9C\x94\033[0m"
TMP_DIR=$(mktemp -d)

exiterr() { echo -e "Error: $1" >&2; exit 1; }

# check vcoclient.py installed
VCOCLIENT=$(which vcoclient.py) 
[[ ! -x ${VCOCLIENT} ]] && { exiterr "Please install vcoclient.py first! To install latest version use: pip3 install vcoclient"; }

# check jq installed
JQCLIENT=$(which jq)
[[ ! -x ${JQCLIENT} ]] && { exiterr "Please install jq first! To install latest version use your OS paket manager"; }

# parameter and helps
display_help() {
    echo "Usage: $0 -u user -p passwd -o vco1-us.velocloud.net -f "my Customer" -r LIZENZ_USAGE " >&2
    echo
    echo "   -h, --help               Print this help"
    echo "   -u, --username           Username of VCO Instance"
    echo "   -p, --password           Password of VCO User"
    echo "   -o, --orchestrator       FQDN or IP address of orchestrator"
    echo "   -f, --filter             Name of Edge or customer to find edge and/or enterprise ID"
    echo "                            Type -f \"Edge Name\" or -f \"Customer Name\" to use the filter"
    echo "   -r, --report             Typ of Report"
    echo
    echo "Selection for a typ of report:"
    echo "LIZENZ_USAGE                Report the avarage troughtput of (all) Edges at last month"
    echo "...Other types of report are comming soon"
    echo
    exit 1
}

# read options
while :
do
   case "$1" in
      -u | --username)
         if [ $# -ne 0 ]; then
            USERNAME="$2"
         fi
         shift 2
         ;;
      -h | --help)
         display_help
         exit 0
         ;;
      -p | --password)
         PASSWORD="$2"
         shift 2
         ;;
      -o | --orchestrator)
         ORCHESTRATOR="$2"
         shift 2
         ;;
      -f | --filter)
         FILTER="$2"
         shift 2
         ;;
      -r | --report)
         REPORT="$2"
         shift 2
         ;;
      --) # End of all options
         shift
         break
         ;;
      -*)
         echo "Error: Unknown option: $1" >&2
         exiterr "Use $0 -h or --help to find correct options"
         ;;
      *)  # No more options
         break
         ;;
   esac
done


# 1st check of parameter and options
check_options() {
   [[ -z ${USERNAME} ]] && { exiterr "Username must be set"; }
   [[ -z ${PASSWORD} ]] && { exiterr "Password must be set"; }
   [[ -z ${ORCHESTRATOR} ]] && { exiterr "Orchestrator FQDN or IP must be set"; }
   [[ -z ${FILTER} ]] && { FILTER="all"; }
   [[ ! -z ${REPORT} ]] && {
      if [ ${REPORT} = "LIZENZ_USAGE" ]; then
         TODAY=$(date '+%F') # or whatever YYYY-MM-DD you need
         START_EPOCH=$(date --date="$(date +'%Y-%m-01') - 1 month" +%s)
         END_EPOCH=$(date --date="$(date +'%Y-%m-01') - 1 second" +%s)
      # edit for more option filter
      elif [ ${REPORT} = "OTHER" ]; then
         exiterr "Unknown Report Typ ${REPORT}"
      else
         exiterr "Unknown Report Typ ${REPORT}"
      fi;
   }
}

# start to run Report script
echo -e "\n\e[4mRunning VeloCloud Report script\e[0m"
export TMPDIR=${TMP_DIR}

# vco login
vco_login() {
   echo -n "Login on ${ORCHESTRATOR}..."
   echo -e "\\rTry to login with username ${USERNAME} ...                          "
   LOGIN=$(bash -c "vcoclient.py --vco=${ORCHESTRATOR} login --username=${USERNAME} --password=${PASSWORD}")
   [[ ${LOGIN} =~ 'error:' ]] && { exiterr "${LOGIN##*$'\n'}"; }
   echo -e "\\r${CHECK_MARK} Login on ${ORCHESTRATOR} done"
   echo
}

# vco logout
vco_logout () {
   echo -n "Logout at ${ORCHESTRATOR}"
   LOGOUT=$(bash -c  "vcoclient.py --vco=${ORCHESTRATOR} logout")
   [[ ${LOGOUT} =~ 'error:' ]] && { exiterr "PANIC: ${LOGOUT##*$'\n'}"; }
   echo -e "\\r${CHECK_MARK} Logout successfully done                   "
   echo             
}


# get data
get_data() {
   vco_login;
   EDGES=$(bash -c "vcoclient.py --vco=${ORCHESTRATOR} --output=json edges_get | jq");
   CUSTOMERS=$(bash -c "vcoclient.py --vco=${ORCHESTRATOR} --output=json operator_customers_get |jq");
   vco_logout;
   EDGE_NAME=$(echo ${EDGES} |jq -r 'keys[]')
   EDGE_NAME=$(printf '%s\n' $EDGE_NAME)
   CUSTOMER_NAME=$(echo ${CUSTOMERS} |jq -r 'keys[]')
   IFS=$'\n'
   set -f
   EDGES_DATA=()
   for line in ${EDGE_NAME}; do
      EDGES_DATA+=$(echo "$line|")
      EDGES_DATA+=$(echo ${EDGES} |jq --arg line $line -r '.'\"$line\"'.activationTime')
      EDGES_DATA+=$(echo "|")
      EDGES_DATA+=$(echo ${EDGES} |jq --arg line $line -r '.'\"$line\"'.edgeState')
      EDGES_DATA+=$(echo "|")
      EDGES_DATA+=$(echo ${EDGES} |jq --arg line $line -r '.'\"$line\"'.enterpriseId')
      EDGES_DATA+=$(echo "|")
      EDGES_DATA+=$(echo ${EDGES} |jq --arg line $line -r '.'\"$line\"'.id')
      EDGES_DATA+=$'\n' 
   done
   #
   CUSTOMER_DATA=()
   for line in ${CUSTOMER_NAME}; do
      CUSTOMER_DATA+=$(echo "$line|")
      CUSTOMER_DATA+=$(echo ${CUSTOMERS} |jq --arg line $line -r '.'\"$line\"'.enterpriseProxyName')
      CUSTOMER_DATA+=$(echo "|")
      CUSTOMER_DATA+=$(echo ${CUSTOMERS} |jq --arg line $line -r '.'\"$line\"'.id')
      CUSTOMER_DATA+=$'\n'
   done
   set +f
   unset IFS
}

get_filter() {
   [[ ${FILTER} == "all" ]] && { echo "No specific filter set, list all edges and customer w/o the given report";
      echo "OUTPUT"
      echo  "${EDGES_DATA}"
      echo "OUTPUT"
      echo "${CUSTOMER_DATA}"
   }
   [[ ${FILTER} != "all" ]] && {
      IFS=$'\n'
      set -f
      for line in ${EDGES_DATA}; do
         [[ ${line} =~ ${FILTER} ]] && { 
            EDGEID=$(echo ${line} |awk -F"|" '{print $5}')
            ENTERPRISEID=$(echo ${line} |awk -F"|" '{print $4}')
            echo "Filter is set to edgeID: ${EDGEID}"
            echo "Filter is set to enterpriseID: ${ENTERPRISEID}"
            #EDGE_NAME=$()
            EDGENAME=$(echo ${line} |awk -F"|" '{print $1}')
            #create Filename
            echo "Write file to:"$(pwd)
            FILENAME="${EDGENAME}.${TODAY}.json"
            echo "{" > ${FILENAME}
            echo "   \"${EDGENAME}\": {" >> ${FILENAME}
            echo "      \"ReportMonth\":\"$(date -d @$START_EPOCH '+%Y-%m')\" {" >> ${FILENAME}
            get_lm
         }
      done;
      for line in ${CUSTOMER_DATA}; do
         [[ ${line} =~ ${FILTER} ]] && { 
            ENTERPRISEID=$(echo ${line} |awk -F"|" '{print $3}')
            echo "Filter is set to enterpriseID: ${ENTERPRISEID}" 
         }
      done;
      set +f
      unset IFS
   }
}

get_lm(){
   vco_login
   IFS=$'\n'
   set -f
   # epoch_to_date=$(date -d @$epoch +%Y-%m-%d_%H:%M)
   # 5 minutes = 300 sec
   # 30 minutes = 1800 sec
   [[ -z ${NEXT_EPOCH} ]] && { NEXT_EPOCH=$((${START_EPOCH}+300));}
   SUMRX=0
   SUMTX=0
   while true; do
      if [[ ${START_EPOCH} -le ${END_EPOCH} ]]; then
         JSONRESULT=$(bash -c "vcoclient.py --vco=${ORCHESTRATOR} --output=json edges_get_lm --enterpriseid=${ENTERPRISEID} --edgeid=${EDGEID} --starttime=\"$(date -d @$START_EPOCH '+%Y-%m-%d %H:%M')\" --endtime=\"$(date -d @$NEXT_EPOCH '+%Y-%m-%d %H:%M')\"")
         LINKRESULT=$(echo ${JSONRESULT} |jq -r 'keys[]')
         for line in ${LINKRESULT}; do
            [[ -z ${NEWDAY} ]] && { NEWDAY+=${line}; echo "         \"Day\":\"$(date -d @$START_EPOCH '+%d')\" {" >> ${FILENAME}; echo -e "\n|0% - - - - - runing - - - - - - - - - - - 100%|"; }
            #link specific aggregate counter for 5 times
            declare AGGLINECOUNT=AGGCOUNT_${line}
            [[ -z ${!AGGLINECOUNT} ]] && { declare AGGCOUNT_${line}=0; }
            #
            if [[ ${!AGGLINECOUNT} -le 4 ]]; then
               # BYTE*X = Value in Bytes of 5 minutes -- MBIT*X = VALUE in MBit/s
               BYTE_RX=$(echo ${JSONRESULT} |jq --arg line $line -r '.'\"$line\"'.bytesRx')
               MBIT_RX=$(echo "scale=2; (${BYTE_RX} / 300) / 125000" |bc -l | sed -e 's/^-\./-0./' -e 's/^\./0./' |sed -z 's/\(.*\)\n$/\1/')
               BYTE_TX=$(echo ${JSONRESULT} |jq --arg line $line -r '.'\"$line\"'.bytesTx')
               MBIT_TX=$(echo "scale=2; (${BYTE_TX} / 300) / 125000" |bc -l | sed -e 's/^-\./-0./' -e 's/^\./0./' |sed -z 's/\(.*\)\n$/\1/')
               declare LINKSUMRX=SUMRX_${line}
               [[ -z ${!LINKSUMRX} ]] && { declare SUMRX_${line}=0; }
               declare LINKSUMTX=SUMTX_${line}
               [[ -z ${!LINKSUMTX} ]] && { declare SUMTX_${line}=0; }
               declare SUMRX_${line}=$(echo "scale=2; ${!LINKSUMRX} + ${MBIT_RX}" |bc -l | sed -e 's/^-\./-0./' -e 's/^\./0./' |sed -z 's/\(.*\)\n$/\1/')
               declare SUMTX_${line}=$(echo "scale=2; ${!LINKSUMTX} + ${MBIT_TX}" |bc -l | sed -e 's/^-\./-0./' -e 's/^\./0./' |sed -z 's/\(.*\)\n$/\1/')
               declare AGGCOUNT_${line}=$((${!AGGLINECOUNT}+1))
            else
               # BYTE*X = Value in Bytes of 5 minutes -- MBIT*X = VALUE in MBit/s
               echo -n "."
               BYTE_RX=$(echo ${JSONRESULT} |jq --arg line $line -r '.'\"$line\"'.bytesRx')
               MBIT_RX=$(echo "scale=2; (${BYTE_RX} / 300) / 125000" |bc -l | sed -e 's/^-\./-0./' -e 's/^\./0./' |sed -z 's/\(.*\)\n$/\1/')
               BYTE_TX=$(echo ${JSONRESULT} |jq --arg line $line -r '.'\"$line\"'.bytesTx')
               MBIT_TX=$(echo "scale=2; (${BYTE_TX} / 300) / 125000" |bc -l | sed -e 's/^-\./-0./' -e 's/^\./0./' |sed -z 's/\(.*\)\n$/\1/')
               declare SUMRX_${line}=$(echo "scale=2; ${!LINKSUMRX} + ${MBIT_RX}" |bc -l | sed -e 's/^-\./-0./' -e 's/^\./0./' |sed -z 's/\(.*\)\n$/\1/')
               declare SUMTX_${line}=$(echo "scale=2; ${!LINKSUMTX} + ${MBIT_TX}" |bc -l | sed -e 's/^-\./-0./' -e 's/^\./0./' |sed -z 's/\(.*\)\n$/\1/')
               declare AVGDATA=AVGTHP_${line}
               [[ -z ${!AVGDATA} ]] && { declare AVGTHP_${line}; }
               declare DAYCOUNT=TIMECOUNT_${line}
               declare AVGTHP_${line}+=$(echo -n "               \"RX${!DAYCOUNT}\":"; echo "scale=2; ${!LINKSUMRX} / 6" |bc -l | sed -e 's/^-\./-0./' -e 's/^\./0./' |sed -z 's/\(.*\)\n$/\1/' |sed -e 's/$/,\n/';)
               declare SUMRX_${line}=0
               declare AVGTHP_${line}+=$(echo -n "               \"TX${!DAYCOUNT}\":"; echo "scale=2; ${!LINKSUMTX} / 6" |bc -l | sed -e 's/^-\./-0./' -e 's/^\./0./' |sed -z 's/\(.*\)\n$/\1/' |sed -e 's/$/,\n/';)
               declare SUMTX_${line}=0
               #new day after 48 times per link
               [[ ${!DAYCOUNT} -eq 48 ]] && { 
                  declare TIMECOUNT_${line}=1; 
                  NEWDAY=$(echo ${NEWDAY} |sed -e "s/${line}//g");
                  echo "            \"Link\":${line} {" >> ${FILENAME};
                  echo ${!AVGDATA} |sed -e 's/,$//' |sed -e 's/,/,\n/g' >> ${FILENAME};
                  echo "            }" >> ${FILENAME};
                  unset AVGTHP_${line};
               }
               [[ ${!DAYCOUNT} -ge 1 && ${!DAYCOUNT} -lt 48 ]] && { declare TIMECOUNT_${line}=$((${!DAYCOUNT}+1)); }
               [[ -z ${!DAYCOUNT} ]] && { declare TIMECOUNT_${line}=1; }
               [[ -z ${NEWDAY} ]] && { echo "         }" >> ${FILENAME}; }
               #
               unset AGGCOUNT_${line}
            fi
         done
         START_EPOCH=$((${START_EPOCH}+300))
         NEXT_EPOCH=$((${NEXT_EPOCH}+300))      
      else
         break
      fi
   done
   set +f
   unset IFS
   vco_logout
}


clean_up() {
   echo "run clean up jobs"
NEXT_EPOCH=""
STARTRX=""
STARTTX=""
}

check_options
get_data
get_filter
clean_up
