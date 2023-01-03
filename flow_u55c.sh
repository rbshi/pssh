#!/bin/bash

# parameters
FPGA_BIT_PATH=~/Workspace/hw/coyote_build/perf_rdma/pr_1/lynx/lynx.runs/impl_1/cyt_top

HOSTBIN_PATH=
HOSTBIN_REMOTE_DIR=
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

# TODO remove this after merge the env MAC version
USER_ENV_MAC=1

# server IDs (u55c)
# NOTE: do not use u55c-01, with only 2022.2 Vivado version
SERVID=(7 8)

if [ $USER_ENV_MAC -eq 0 ]; then
	DRIVER_REMOTE_PATH=/mnt/scratch/runshi/coyote_drv_old.ko
else
	DRIVER_REMOTE_PATH=/mnt/scratch/runshi/coyote_drv.ko
fi

# args
PROGRAM_FPGA=$1
HOT_RESET=$2
UPDATE_HOSTBIN=$3

alveo_program()
{
	SERVERADDR=$1
	SERVERPORT=$2
	BOARDSN=$3
	DEVICENAME=$4
	BITPATH=$5
	vivado -nolog -nojournal -mode batch -source $SCRIPT_DIR/program_alveo.tcl -tclargs $SERVERADDR $SERVERPORT $BOARDSN $DEVICENAME $BITPATH
}

if [ "$#" -ne 3 ]; then
  echo "Usage: $0 program_fpga<0/1> hot_reset<0/1> update_hostbin<0/1>" >&2
  exit 1
fi

if ! [ -x "$(command -v vivado)" ]; then
	echo "Vivado does NOT exist in the system."
	exit 1
fi

# generate host name list
BOARDSN=(XFL1QOQ1ATTYA XFL1O5FZSJEIA XFL1QGKZZ0HVA XFL11JYUKD4IA XFL1EN2C02C0A XFL1NMVTYXR4A XFL1WI3AMW4IA XFL1ELZXN2EGA XFL1W5OWZCXXA XFL1H2WA3T53A)
for servid in ${SERVID[@]}; do 
	hostlist+="alveo-u55c-$(printf "%02d" $servid) "
done

FPGAMAC0=(000A350B22D8 000A350B22E8 000A350B2340 000A350B24D8 000A350B23B8 000A350B2448 000A350B2520 000A350B2608 000A350B2498 000A350B2528)
FPGAMAC1=(000A350B22DC 000A350B22EC 000A350B2344 000A350B24DC 000A350B23BC 000A350B244C 000A350B2524 000A350B260C 000A350B249C 000A350B252C)
FPGAIP0=(0afd4a44 0afd4a48 0afd4a4c 0afd4a50 0afd4a54 0afd4a58 0afd4a5c 0afd4a60 0afd4a64 0afd4a68)
FPGAIP1=(0afd4a45 0afd4a49 0afd4a4d 0afd4a51 0afd4a55 0afd4a59 0afd4a5d 0afd4a61 0afd4a65 0afd4a69)

# STEP1: Program FPGA
if [ $PROGRAM_FPGA -eq 1 ]; then
	# activate servers (login with passwd to enable the nfs home mounting)
	echo "Activating server..."
	parallel-ssh -H "$hostlist" -A -O PreferredAuthentications=password "echo Login success!"
	# enable hardware server
	echo "Enabling Vivado hw_server..."
	# this step will be timeout after 2 secs to avoid the shell blocking
	parallel-ssh -H "$hostlist" -t 2 "/tools/Xilinx/Vivado/2022.1/bin/hw_server &"
	echo "Programming FPGA..."
	for servid in "${SERVID[@]}"; do
		boardidx=$(expr $servid - 1)
		alveo_program alveo-u55c-$(printf "%02d" $servid) 3121 ${BOARDSN[boardidx]} xcu280_u55c_0 $FPGA_BIT_PATH
	done
	read -p "FPGA programmed. Press enter to continue or Ctrl-C to exit."
fi

# STEP2: Hot reset
if [ $HOT_RESET -eq 1 ]; then
	#NOTE: put -x '-tt' (pseudo terminal) here for sudo command
	echo "Removing the driver..."
	parallel-ssh -H "$hostlist" -x '-tt' "sudo rmmod fpga_drv coyote_drv"
	echo "Hot resetting PCIe..."	
	parallel-ssh -H "$hostlist" -x '-tt' 'sudo /opt/cli/program/pci_hot_plug "$(hostname -s)"'
	read -p "Hot-reset done. Press enter to load the driver or Ctrl-C to exit."
	echo "Loading driver..."

	if [ $USER_ENV_MAC -eq 0 ]; then
		parallel-ssh -H "$hostlist" -x '-tt' "sudo insmod $DRIVER_REMOTE_PATH && sudo /opt/cli/program/fpga_chmod 0"
	else
		for servid in "${SERVID[@]}"; do
			boardidx=$(expr $servid - 1)
			parallel-ssh -H "alveo-u55c-$(printf "%02d" $servid)" -x '-tt' "sudo insmod $DRIVER_REMOTE_PATH ip_addr_q0=${FPGAIP0[boardidx]} ip_addr_q1=${FPGAIP1[boardidx]} mac_addr_q0=${FPGAMAC0[boardidx]} mac_addr_q1=${FPGAMAC1[boardidx]}"
		done
		parallel-ssh -H "$hostlist" -x '-tt' "sudo /opt/cli/program/fpga_chmod 0"
	fi
	echo "Driver loaded."
fi

# STEP3: Upload host bin
if [ $UPDATE_HOSTBIN -eq 1 ]; then
	echo "Copying program to hosts"
	parallel-scp -H "$hostlist" $HOSTBIN_PATH $HOSTBIN_REMOTE_DIR
fi

#TODO: STEP4: Run host bin

exit 0