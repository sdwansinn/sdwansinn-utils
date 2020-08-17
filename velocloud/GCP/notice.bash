#!/bin/bash
echo "script is on edition state"
exit 0



# get projects list
gcloud projects list
# create your own project
gcloud projects create a1-smart-vpn --name="A1 Digital smartVPN" --labels=type=smart-vpn
# set a default project
##gcloud beta artifacts packages list --project=my-project
### valued-vault-272112
gcloud beta artifacts packages list --project=valued-vault-272112

# get service-account for instanze deployment
gcloud beta iam service-accounts list --filter "Compute Engine"

# create bucket and upload image file ! file must be named as disk.raw !
# tar --format=oldgnu -Sczf /tmp/compressed-image.tar.gz disk.raw
gcloud compute images create velo-321 --project=valued-vault-272112 --source-uri=https://storage.googleapis.com/isoimages_sdwan/velo-3.2.1.tar.gz --storage-location=eu --guest-os-features MULTI_IP_SUBNET

# create two vpc (networks), one for WAN side and one for LAN side in your region who planned your deployment
gcloud compute networks create velo-vpc-private --project=valued-vault-272112 --description=velocloud\ LAN --subnet-mode=custom --bgp-routing-mode=regional
gcloud compute networks create velo-vpc-public --project=valued-vault-272112 --description=velocloud\ WAN --subnet-mode=custom --bgp-routing-mode=regional

# create subnets on vpc
gcloud compute networks subnets create public-vpc --project=valued-vault-272112 --range=10.10.2.0/24 --network=velo-vpc-public --region=europe-west2
gcloud compute networks subnets create private-vpc --project=valued-vault-272112 --range=10.10.3.0/24 --network=velo-vpc-private --region=europe-west2

# create firewall rule for WAN vpc
gcloud compute --project=valued-vault-272112 firewall-rules create ingress-public-vpc-vcmp --direction=INGRESS --priority=100 --network=velo-vpc-public --action=ALLOW --rules=udp:2426 --source-ranges=0.0.0.0/0

# create new default route for private network with virtual edge as next hop
# If the do not delete the default gw of gcloud flag set, the will this route work as backup route. Access from Internet to pvc is denied by default. Else use following to get string to delete the default route.
gcloud beta compute routes create priv-default-rt --project=valued-vault-272112 --description=SD-WAN\ GW\ is\ next\ hop\ for\ default\ route --network=velo-vpc-private --priority=1 --destination-range=0.0.0.0/0 --next-hop-address=10.10.3.5
DFROUTEDELETE=$(gcloud compute routes list --filter 1000 | awk '{ if ($2 == "velo-vpc-private") { print $1 }}')
gcloud compute routes delete ${DFROUTEDELETE}

# create internal static address for velo-vpc-private
gcloud compute addresses create velo-static-private --addresses 10.10.3.5 --region=europe-west2 --subnet=private-vpc

# create instanze
gcloud beta compute --project=valued-vault-272112 instances create vvce1-gcp-euwest2 --zone=europe-west2-c --machine-type=n1-standard-2 --network-interface subnet=public-vpc --network-interface private-network-ip=velo-static-private,subnet=private-vpc,no-address --can-ip-forward --maintenance-policy=MIGRATE --service-account=798906366602-compute@developer.gserviceaccount.com --scopes=https://www.googleapis.com/auth/devstorage.read_only,https://www.googleapis.com/auth/logging.write,https://www.googleapis.com/auth/monitoring.write,https://www.googleapis.com/auth/servicecontrol,https://www.googleapis.com/auth/service.management.readonly,https://www.googleapis.com/auth/trace.append --image=velo-321 --image-project=valued-vault-272112 --boot-disk-size=10GB --boot-disk-type=pd-standard --boot-disk-device-name=vvce1-gcp-euwest2 --reservation-affinity=any --tags vvce1-gcp-euwest2
gcloud compute instances add-metadata vvce1-gcp-euwest2 --metadata serial-port-enable=TRUE --zone=europe-west2-c
gcloud compute connect-to-serial-port root@vvce1-gcp-euwest2 --zone=europe-west2-c

# login root velocloud and paste code as following
./pts_writer -n /dev/pts/2 "ip link set br-network0 down"
./pts_writer -n /dev/pts/2 "brctl delbr br-network0"
./pts_writer -n /dev/pts/2 "ip link set eth0 dynamic on"
./pts_writer -n /dev/pts/2 "udhcpc -i eth0"
./pts_writer -n /dev/pts/2 "activate.py -s vco1-fra.a1.digital 4FR8-FPGK-5U3X-PR4Q"
