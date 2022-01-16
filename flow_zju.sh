#!/bin/bash 

# activate the nfs home folder via passwd ssh, enable the pub key
act_sshpass()
{
	SERVERADDR=$1
	PASS=$2
	echo "Activating server $1"
	sshpass -p "$PASS" ssh runshi@$SERVERADDR "echo Success!"
}

alveo_program()
{
	SERVERADDR=$1
	SERVERPORT=$2
	BITPATH=$3
	vivado -nolog -nojournal -mode batch -source program_zju.tcl -tclargs ${SERVERADDR} ${SERVERPORT} ${BITPATH}
}

if [ "$#" -ne 2 ]; then
  echo "Usage: $0 program_fpga<0/1> update_hostbin<0/1>" >&2
  exit 1
fi


# Parameters
FPGABITPATH=/home/runshi/Workspace/hw/coyote/hw/build_5/lynx/lynx.runs/impl_1/top
DRIVER=/home/runshi/Workspace/hw/coyote/driver/fpga_drv.ko
HOSTBIN=/home/runshi/Workspace/hw/coyote/sw/examples/rdma_complete/build/main
# HOSTBIN=/home/runshi/Workspace/hw/coyote/sw/examples/test_axil/build/main
REMOTEDIR=/home/runbin
PROGRAM_FPGA=$1
UPDATE_HOSTBIN=$2


# enable hardware server
# echo "Enabling hardware server"
# pssh -h hosts_alveo.txt "/opt/tools/Xilinx/Vivado/2020.1/bin/loader -exec hw_server &"


if [ $PROGRAM_FPGA -eq 1 ]; then
	echo "Programming FPGA..."
	alveo_program hk.rbshi.me 3121 $FPGABITPATH
	# cold reboot is required (TODO)
	echo "Cold reboot the machine"
	pssh -h hosts_zju.txt "sudo reboot"
	# wait for around 100 sec
	echo "Will sleep 100 sec..."
	sleep 100
	# rmmod xdma
	echo "Remove the auto-loaded xdma driver"
	pssh -h hosts_zju.txt "sudo rmmod xdma_driver"
	# load coyote driver
	echo "Load coyote driver"
	pssh -h hosts_zju.txt "sudo insmod $REMOTEDIR/fpga_drv.ko"
fi

# upload host binary
if [ $UPDATE_HOSTBIN -eq 1 ]; then
	echo "Copying program to hosts"
	pscp -h hosts_zju.txt $HOSTBIN $REMOTEDIR
fi

echo "Running the program"
DATESTAMP=`date +%Y%m%d%H%M`
pssh -i -h hosts_zju.txt "if [ -e r7 ]; then \
		sudo ./main -i 0 > log/r7_$DATESTAMP.log && scp log/r7_$DATESTAMP.log runshi@hk.rbshi.me:/home/runshi/log/ \
	;else \
		sleep 2 && sudo ./main -i 1 > log/r8_$DATESTAMP.log && scp log/r8_$DATESTAMP.log runshi@hk.rbshi.me:/home/runshi/log/ \
	; fi"

















exit 0