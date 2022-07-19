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

if [ "$#" -ne 4 ]; then
  echo "Usage: $0 program_fpga<0/1> reboot_host<0/1> update_hostbin<0/1> run_hostbin<0/1>" >&2
  exit 1
fi


# Parameters
# FPGABITPATH=/home/runshi/Workspace/hw/coyote_dev/hw/build3/lynx/lynx.runs/impl_1/top
FPGABITPATH=/home/runshi/Workspace/hw/corundum_2/fpga/mqnic/AU280/fpga_100g/fpga/fpga
DRIVER=/home/runshi/Workspace/hw/coyote_dev/driver/fpga_drv.ko
HOSTBIN=/home/runshi/Workspace/hw/coyote/sw/examples/tm/build/main
REMOTEDIR=/home/runbin
PROGRAM_FPGA=$1
REBOOT_HOST=$2
UPDATE_HOSTBIN=$3
RUN_HOSTBIN=$4


if [ $PROGRAM_FPGA -eq 1 ]; then
	echo "Programming FPGA..."
	alveo_program hk.rbshi.me 3121 $FPGABITPATH
fi


# Node0 (server7) 10.0.0.128
# Node1 (server8) 10.0.0.129

if [ $REBOOT_HOST -eq 1 ]; then
	# cold reboot is required (TODO)
	echo "Cold reboot the machine"
	pssh -h hosts_zju.txt "sudo reboot"
	# wait for around 100 sec
	echo "Will sleep 100 sec..."
	sleep 100
	# rmmod xdma
	# echo "Remove the auto-loaded xdma driver"
	# pssh -h hosts_zju.txt "sudo rmmod xdma_driver"
	# load coyote driver
	echo "Load coyote driver"
	pssh -h hosts_zju.txt "sudo insmod $REMOTEDIR/fpga_drv.ko"
fi

# upload host binary
if [ $UPDATE_HOSTBIN -eq 1 ]; then
	echo "Copying program to hosts"
	pscp -h hosts_zju.txt $HOSTBIN $REMOTEDIR
fi

if [ $RUN_HOSTBIN -eq 1 ]; then
	echo "Running the program"
	DATESTAMP=`date +%Y%m%d%H%M`
	pssh -i -h hosts_zju.txt "if [ -e r7 ]; then \
			sudo ./main -i 0 > log/r7_$DATESTAMP.log && scp log/r7_$DATESTAMP.log runshi@hk.rbshi.me:/home/runshi/log/ \
		;else \
			sleep 2 && sudo ./main -i 1 > log/r8_$DATESTAMP.log && scp log/r8_$DATESTAMP.log runshi@hk.rbshi.me:/home/runshi/log/ \
		; fi"
fi



exit 0