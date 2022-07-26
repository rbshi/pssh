#!/bin/bash

# parameters
LOCAL_DIR=~/Workspace/tm/humongouslock
REMOTE_DIR=/local/home/runshi/Workspace/tm/
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

# server IDs (u55c)
SERVID=(7 8 9 10)

# if [ "$#" -ne 3 ]; then
#   echo "Usage: $0 program_fpga<0/1> reboot_host<0/1> update_hostbin<0/1>" >&2
#   exit 1
# fi

# generate host name list
for servid in ${SERVID[@]}; do
	hostlist+="alveo-u55c-$(printf "%02d" $servid) "
done

# STEP1: activate servers (login with passwd to enable the nfs home mounting)
echo "Activating server..."
parallel-ssh -H "$hostlist" -A -O PreferredAuthentications=password "echo Login success!"

# STEP2: rsync the workspace
echo "Confirm the existance of remote dir..."
parallel-ssh -H "$hostlist" "mkdir -p $REMOTE_DIR"
echo "Syncing the workspace..."
parallel-rsync -r -H "$hostlist" $LOCAL_DIR $REMOTE_DIR

# STEP3: Run the host bin


exit 0