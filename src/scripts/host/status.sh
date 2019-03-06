#!/bin/bash
PROJECT_NAME="${1}"
ROOT_DIR="${2}"
HOST_TYPE="${3}"
HOST_ID="${4}"
HOST_ROLE="${5}"
STATUS_TOPIC_ID="${6}"
STORAGE_ACCOUNT_ID="${7}"
KEYVAULT_ID="${8}"

# Loop for a number of seconds by default, with a random addition of 0-9 seconds
LOOPTIME=60

while true; do
	STARTTIME=$(date +%s)
	# Set status and reset watchdog timer
	# Do not use the watchdog to signal failures of any of the following commands
	# The watchdog is only there to make sure that the script itself keeps running
	systemd-notify --status="Started run on $(date)" WATCHDOG=1

	# Announce the current status
	. ${ROOT_DIR}/host/announce.sh

	# notify watchdog
	systemd-notify --status="Waiting for next invocation"

	# Calculate our next run time
	ENDTIME=$(date +%s)
	SLEEPTIME=$(( LOOPTIME - (ENDTIME - STARTTIME) + RANDOM % 10 ))

	# Sanity check the sleeptime, if we get a negative time (due to skew )
	[ $SLEEPTIME -le 0 -o $SLEEPTIME -gt $LOOPTIME ] && SLEEPTIME=$LOOPTIME
	sleep $SLEEPTIME
done
