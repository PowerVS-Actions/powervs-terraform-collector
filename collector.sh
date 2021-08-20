#!/bin/bash

TMP_POWERVSINSTANCES_LOG="/tmp/powervs-instances-log"
DC_LOCATIONS=()

# Trap ctrl-c and call ctrl_c()
trap ctrl_c INT
function ctrl_c() {
    echo "Bye!"
}

function connect_ibm_cloud(){
	# IBM Cloud Login
	echo "Connecting to IBM Cloud..."
	local API_KEY="$1"
    if [ -z "$API_KEY" ]; then
        echo "API KEY was not set."
        exit
    fi
    ibmcloud update -f > /dev/null 2>&1
    ibmcloud plugin update --all > /dev/null 2>&1
    ibmcloud login --no-region --apikey "$APY_KEY" > /dev/null 2>&1
}

function get_powervs_services_data() {
	# Collect PowerVS service information from IBM Cloud
	echo "Collecting PowerVS raw data from IBM Cloud..."
	true > "$TMP_POWERVSINSTANCES_LOG"
	ibmcloud pi service-list --json | jq '.[] | "\(.CRN),\(.Name)"' >> $TMP_POWERVSINSTANCES_LOG
}

function get_powervs_raw_data() {

	local TOTAL_LON=0
	local TOTAL_DE=0
	local TOTAL_TOR=0
	local TOTAL_MON=0
	local TOTAL_SYD=0
	local TOTAL_TOK=0
	local TOTAL_OSA=0
	local TOTAL_SAO=0
	local TOTAL_DAL=0
	local TOTAL_US_EAST=0
	local TOTAL_US_SOUTH=0
	local ACCOUNT=$1
	local API_KEY=$2

	while read -r line; do

		local POWERVS_NAME
		local POWERVS_ZONE
		local POWERVS_INSTANCE_ID

		POWERVS_NAME=$(echo "$line" | awk -F ',' '{print $2}')
		POWERVS_ZONE=$(echo "$line" | awk -F ':' '{print $6}')
		POWERVS_INSTANCE_ID=$(echo "$line" | awk -F ':' '{print $8}')
		SLOC=$POWERVS_ZONE

		if [[ $SLOC == *"lon"* ]]; then
			SREG="lon"
			((TOTAL_LON=TOTAL_LON+1))
		elif [[ $SLOC == *"de"* ]]; then
			SREG="eu-de"
			((TOTAL_DE=TOTAL_DE+1))
		elif [[ $SLOC == *"tor"* ]]; then
			SREG="tor"
			((TOTAL_TOR=TOTAL_TOR+1))
		elif [[ $SLOC == *"mon"* ]]; then
			SREG="mon"
			((TOTAL_MON=TOTAL_MON+1))
		elif [[ $SLOC == *"syd"* ]]; then
			SREG="syd"
			((TOTAL_SYD=TOTAL_SYD+1))
		elif [[ $SLOC == *"tok"* ]]; then
			SREG="tok"
			((TOTAL_TOK=TOTAL_TOK+1))
		elif [[ $SLOC == *"osa"* ]]; then
			SREG="osa"
			((TOTAL_OSA=TOTAL_OSA+1))
		elif [[ $SLOC == *"dal"* ]]; then
			SREG="dal"
			((TOTAL_DAL=TOTAL_DAL+1))
		elif [[ $SLOC == *"east"* ]]; then
			SREG="east"
			((TOTAL_US_EAST=TOTAL_US_EAST+1))
		elif [[ $SLOC == *"south"* ]]; then
			SREG="south"
			((TOTAL_US_SOUTH=TOTAL_US_SOUTH+1))
		elif [[ $SLOC == *"sao"* ]]; then
			SREG="sao"
			((TOTAL_SAO=TOTAL_SAO+1))
		else
			SREG="none"
		fi

		DC_LOCATIONS[${#DC_LOCATIONS[@]}]=$SLOC

		process_data "$API_KEY" "$POWERVS_INSTANCE_ID" "$SREG" "$POWERVS_ZONE" "$POWERVS_NAME" "$ACCOUNT"

	done < $TMP_POWERVSINSTANCES_LOG
}

function process_data(){

	# Variables
	API_KEY="$1"
	POWERVS_ID="$2"
	IBMCLOUD_REGION="$3"
	IBMCLOUD_ZONE="$4"
	PVSNAME="$5"
	TERRAFORM_LOG="/tmp/pvs-terraform.log"
	ACCOUNT="$6"

	TODAY=$(date +'%m/%d/%Y')
	TIME=$(TZ=UTC date +"%H:%M:%S")

	if [ $# -eq 0 ]; then
		echo "Please, set the correct parameters to run this script."
		exit
	fi
	if [ -z "$API_KEY" ]; then
		echo "Please set API_KEY."
		exit
	fi
	if [ -z "$POWERVS_ID" ]; then
		echo "Please set POWERVS_ID."
		exit
	fi
	if [ -z "$IBMCLOUD_REGION" ]; then
		echo "Please set IBMCLOUD_REGION."
		exit
	fi
	if [ -z "$IBMCLOUD_ZONE" ]; then
		echo "Please set IBMCLOUD_ZONE."
		exit
	fi

	echo "> collecting data from $PVSNAME ($IBMCLOUD_REGION)..."
	true > "$TERRAFORM_LOG"

	# Run Terraform
	terraform init

	terraform apply -auto-approve -var ibmcloud_api_key="$API_KEY" -var power_instance_id="$POWERVS_ID" -var ibmcloud_region="$IBMCLOUD_REGION" -var ibmcloud_zone="$IBMCLOUD_ZONE" > /dev/null 2>&1

	# Convert output to JSON
	terraform output -json >> "$TERRAFORM_LOG"

	# Parse the JSON
	ID=$(jq -r '.powervs_id.value' < "$TERRAFORM_LOG")
	REGION=$(jq -r '.region.value' < "$TERRAFORM_LOG")
	NINSTANCES=$(jq -r  '.instance_count.value' < "$TERRAFORM_LOG")
	PROCESSORS=$(jq -r '.instance_processors.value' < "$TERRAFORM_LOG")
	MEMORY=$(jq -r '.instance_memory.value' < "$TERRAFORM_LOG")
	TIER1=$(jq -r '.instance_ssd.value' < "$TERRAFORM_LOG")
	TIER3=$(jq -r '.instance_standard.value' < "$TERRAFORM_LOG")

	if [ -z "$NINSTANCES" ]; then
		NINSTANCES=0
	fi
	if [ -z "$PROCESSORS" ]; then
		PROCESSORS=0
	fi
	if [ -z "$MEMORY" ]; then
		MEMORY=0
	fi
	if [ -z "$TIER1" ]; then
		TIER1=0
	fi
	if [ -z "$TIER3" ]; then
		TIER3=0
	fi

	PVSNAME=$(echo "$PVSNAME" | tr -d "\"")

	echo "$TODAY,$TIME,$ACCOUNT,$ID,$PVSNAME,$REGION,$NINSTANCES,$PROCESSORS,$MEMORY,$TIER1,$TIER3"

	echo "$TODAY,$TIME,$ACCOUNT,$ID,$PVSNAME,$REGION,$NINSTANCES,$PROCESSORS,$MEMORY,$TIER1,$TIER3" >> "$ACCOUNT.csv"

	echo "$TODAY,$TIME,$ACCOUNT,$ID,$PVSNAME,$REGION,$NINSTANCES,$PROCESSORS,$MEMORY,$TIER1,$TIER3" >> ./all.csv

	INFO=(
	"*********************************************"
	"PowerVS Name: $PVSNAME"
	"PowerVS ID: $ID"
	"Region: $REGION"
	"Number of instances: $NINSTANCES"
	"Number of processors: $PROCESSORS"
	"Amount of memory: $MEMORY"
	"Amount of Tier1 storage: $TIER1"
	"Amount of Tier3 storage: $TIER3"
	"*********************************************"
	)

	TODAY=$(echo "$TODAY" | tr -d "/")
	printf '%s\n' "${INFO[@]}"

	# Destroy the resources
	terraform destroy -auto-approve -var ibmcloud_api_key="$API_KEY" -var power_instance_id="$POWERVS_ID" -var ibmcloud_region="$IBMCLOUD_REGION" -var ibmcloud_zone="$IBMCLOUD_ZONE" > /dev/null 2>&1
}

run (){

	TODAY=$(date +'%m/%d/%Y')

	while read -r line; do
		ACCOUNT=$(echo "$line" | awk -F ',' '{print $1}')
		API_KEY=$(echo "$line" | awk -F ',' '{print $2}')
		echo "Collecting data from $ACCOUNT..."
		connect_ibm_cloud "$API_KEY"
		get_powervs_services_data
		get_powervs_raw_data "$ACCOUNT" "$API_KEY"
	done < ./api_keys

	# remove lines with null entries
	sed '/null/d' ./all.csv > /tmp/all.csv
	rm -f ./all.csv
	mv /tmp/all.csv ./

	mkdir -p ./output
	cp ./all.csv ./"$(echo "$TODAY" | tr -d "/")"-all.csv
	mv ./*.csv ./output
}

run "$@"
