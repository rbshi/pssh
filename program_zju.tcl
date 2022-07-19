
set serveraddr  [lindex $::argv 0]
set serverport [lindex $::argv 1]
set bitpath [lindex $::argv 2]

# variable boardsns
# server 7, 8
variable boardsns
array set boardsns {21770202700VA 21770205K022A}
set devicename xcu280_0

puts "${bitpath}.bit"

foreach boardsn [array get boardsns] {
	open_hw_manager
	connect_hw_server -url ${serveraddr}:${serverport} -allow_non_jtag
	open_hw_target ${serveraddr}:${serverport}/xilinx_tcf/Xilinx/${boardsn}
	current_hw_device [get_hw_devices ${devicename}]
	# refresh_hw_device -update_hw_probes false [lindex [get_hw_devices ${devicename}] 0]

	set_property PROGRAM.FILE ${bitpath}.bit [get_hw_devices ${devicename}]
	set_property PROBES.FILE ${bitpath}.ltx [get_hw_devices ${devicename}]
	set_property FULL_PROBES.FILE ${bitpath}.ltx [get_hw_devices ${devicename}]
	program_hw_devices [get_hw_devices ${devicename}]
	# refresh_hw_device [lindex [get_hw_devices ${devicename}] 0]
	close_hw_target ${serveraddr}:${serverport}/xilinx_tcf/Xilinx/${boardsn}
	close_hw_manager	
}

