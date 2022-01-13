#!/bin/bash 
###############################################################################
#Script Name    : commands.sh                       
#Description    : execute multiple commands on multiple servers                                                                     
#Author         : Aaron Kili Kisinga       
#Email          : aaronkilik@gmail.com 
################################################################################
echo
# show system uptime
uptime
echo
# show who is logged on and what they are doing
who
echo
# show top 5 processe by RAM usage 
ps -eo cmd,pid,ppid,%mem,%cpu --sort=-%mem | head -n 6

exit 0