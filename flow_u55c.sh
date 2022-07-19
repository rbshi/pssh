#!/bin/bash

# parameters
FPGABITPATH=~/Workspace/hw/coyote_build/build11/lynx/lynx.runs/impl_1/top
DRIVERPATH=/local/home/runshi/fpga_drv.ko
HOSTBIN=~/Workspace/hw/coyote/sw/examples/tm/build/main
REMOTEDIR=/home/runshi/
PROGRAM_FPGA=$1
HOT_RESET=$2
UPDATE_HOSTBIN=$3

# server IDs (u55c)
SERVID=(9 10)

alveo_program()
{
	SERVERADDR=$1
	SERVERPORT=$2
	BOARDSN=$3
	DEVICENAME=$4
	BITPATH=$5
	vivado -nolog -nojournal -mode batch -source program_alveo.tcl -tclargs $SERVERADDR $SERVERPORT $BOARDSN $DEVICENAME $BITPATH
}

if [ "$#" -ne 4 ]; then
  echo "Usage: $0 program_fpga<0/1> reboot_host<0/1> update_hostbin<0/1> run_hostbin<0/1>" >&2
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
	echo "Activating server"
	parallel-ssh -H "$hostlist" -A -O PreferredAuthentications=password "echo Login success!"
	# enable hardware server
	echo "Enabling hw_server"
	# this step will be timeout after 2 secs to avoid the shell blocking
	parallel-ssh -H "$hostlist" -t 2 "source /tools/Xilinx/Vivado/2022.1/settings64.sh && hw_server &"
	echo "Programming FPGA..."
	for servid in "${SERVID[@]}"; do
		boardidx=$(expr $servid - 1)
		alveo_program alveo-u55c-$(printf "%02d" $servid).ethz.ch 3121 ${BOARDSN[boardidx]} xcu280_u55c_0 $FPGABITPATH
	done
	read -p "Program FPGA is done. Press enter to do hot-reset or Ctrl-C to exit."
fi

# STEP2: Reboot Host (FIXME: change to hot reset)
if [ $REBOOT_HOST -eq 1 ]; then
	read -p "Confirm the server is rebooted"
	parallel-ssh -H "$hostlist" -A -O PreferredAuthentications=password "echo Login success!"
	echo "Load Coyote driver"
	parallel-ssh -H "$hostlist" -x '-tt' "sudo insmod $DRIVERPATH && sudo /opt/user_tools/get_fpga 0"
	echo "Load driver success"
fi

# STEP3: Upload host bin
if [ $UPDATE_HOSTBIN -eq 1 ]; then
	echo "Copying program to hosts"
	parallel-scp -H "$hostlist" $HOSTBIN $REMOTEDIR
fi

#TODO: STEP4: Run host bin

exit 0