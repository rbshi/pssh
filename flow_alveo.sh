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
	BOARDSN=$3
	DEVICENAME=$4
	BITPATH=$5
	vivado -mode batch -source program_alveo.tcl -tclargs ${SERVERADDR} ${SERVERPORT} ${BOARDSN} ${DEVICENAME} ${BITPATH} -notrace
}

# Parameters
ALVEOPASS=OpenR1sc1102
TARGETBITPATH=/home/runshi/Workspace/hw/coyote/hw/build_5/lynx/lynx.runs/impl_2/top

# activate servers
act_sshpass alveo4b.ethz.ch $ALVEOPASS
act_sshpass alveo4c.ethz.ch $ALVEOPASS

# enable hardware server
# echo "Enabling hardware server"
# pssh -h hosts_alveo.txt "/opt/tools/Xilinx/Vivado/2020.1/bin/loader -exec hw_server &"

echo "Programming FPGA"
alveo_program alveo4b.ethz.ch 3121 21770297400LA xcu280_0 $TARGETBITPATH
alveo_program alveo4c.ethz.ch 3121 217702974013A xcu280_0 $TARGETBITPATH


exit 0