#!/bin/bash

# parameters
FPGA_BIT_PATH=~/Workspace/hw/coyote_build/build11/lynx/lynx.runs/impl_2/top
DRIVER_REMOTE_PATH=/local/home/runshi/fpga_drv.ko
HOSTBIN_PATH=~/Workspace/hw/coyote/sw/examples/tm/build/main
HOSTBIN_REMOTE_DIR=/home/runshi/
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )


# server IDs (u55c)
SERVID=(9 10)


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
  echo "Usage: $0 program_fpga<0/1> reboot_host<0/1> update_hostbin<0/1>" >&2
  exit 1
fi

if ! [ -x "$(command -v vivado)" ]; then
	echo "Vivado does NOT exist in the system."
	exit 1
fi

# generate host name list
BOARDSN=(XFL1QOQ1ATTYA XFL1O5FZSJEIA XFL1QGKZZ0HVA XFL11JYUKD4IA XFL1EN2C02C0A XFL1NMVTYXR4A XFL1WI3AMW4IA XFL1ELZXN2EGA XFL1W5OWZCXXA XFL1H2WA3T53A)
for servid in ${SERVID[@]}; do 
	hostlist+="alveo-u55c-$(printf "%02d" $servid).ethz.ch "
done

# STEP1: Program FPGA
if [ $PROGRAM_FPGA -eq 1 ]; then
	# activate servers (login with passwd to enable the nfs home mounting)
	echo "Activating server..."
	parallel-ssh -H "$hostlist" -A -O PreferredAuthentications=password "echo Login success!"
	# enable hardware server
	echo "Enabling Vivado hw_server..."
	# this step will be timeout after 2 secs to avoid the shell blocking
	parallel-ssh -H "$hostlist" -t 2 "source /tools/Xilinx/Vivado/2022.1/settings64.sh && hw_server &"
	echo "Programming FPGA..."
	for servid in "${SERVID[@]}"; do
		boardidx=$(expr $servid - 1)
		alveo_program alveo-u55c-$(printf "%02d" $servid).ethz.ch 3121 ${BOARDSN[boardidx]} xcu280_u55c_0 $FPGA_BIT_PATH
	done
	read -p "FPGA programmed. Press enter to continue or Ctrl-C to exit."
fi

# STEP2: Reboot Host (FIXME: change to hot reset)
if [ $HOT_RESET -eq 1 ]; then
	#NOTE: put -x '-tt' (pseudo terminal) here for sudo command
	echo "Removing the driver..."
	parallel-ssh -H "$hostlist" -x '-tt' "sudo rmmod fpga_drv"
	echo "Hot resetting PCIe..."	
	parallel-ssh -H "$hostlist" -x '-tt' 'sudo /opt/user_tools/hot_plug_boot "$(hostname -s)"'
	read -p "Hot-reset done. Press enter to load the driver or Ctrl-C to exit."
	echo "Loading driver..."
	parallel-ssh -H "$hostlist" -x '-tt' "sudo insmod $DRIVER_REMOTE_PATH && sudo /opt/user_tools/get_fpga 0"
	echo "Driver loaded."
fi

# STEP3: Upload host bin
if [ $UPDATE_HOSTBIN -eq 1 ]; then
	echo "Copying program to hosts"
	parallel-scp -H "$hostlist" $HOSTBIN_PATH $HOSTBIN_REMOTE_DIR
fi

#TODO: STEP4: Run host bin

exit 0