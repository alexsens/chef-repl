#!/bin/bash

MASTER=<%= @master_host %>
REPL_USER=<%= @repl_user %>
ROOT_PASS=<%= @mysql_root_pass %>
REPL_PASS=<%= @mysql_repl_pass %>
mysql -u"$REPL_USER" -p"$REPL_PASS" -h"$MASTER" --connect-timeout=15 -e 'SELECT VERSION()' > /dev/null
if [ $? -eq 0 ] ; then
	echo "slave is OK"
else
	mysql -h127.0.0.1 -uroot -p"$ROOT_PASS" -e "STOP SLAVE"
	echo "slave stopped"
fi
