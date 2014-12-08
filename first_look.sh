#!/bin/bash

# Copyright (c) 2009-2014 Vladimir Fedorkov (http://astellar.com/)
# All rights reserved.                                                         
#                                                                              
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
# OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
# HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
# LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
# OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
# SUCH DAMAGE.

# config
MNAME=$1
MHOST=$2
MUSER=$3
MPASS=$4
MPORT=$5

# Percona Tools path
PT_BIN_PATH="./bin"

CMDL_PASS="--password=$MPASS --port=$MPORT"

### Preparing for start
export PATH=$PATH:$PT_BIN_PATH

mkdir -p $MNAME
if [ ! -d $MNAME ]; then
    echo "Can't create output directory: $DIGEST_DIR"
    exit 1
fi

### FIXME add error handling for directory creation

if [ "MHOST" == 'localhost' || "MHOST" == '127.0.0.1' || "MHOST" == '0' ] ; then
    echo "Collecting OS data for host=$MHOST system name=$MNAME:"

    echo -n "Gathering system summary..."
    $PT_BIN_PATH/pt-summary > $MNAME/sys-pt-summary.log

    echo -n "iostat..."
    iostat -dx 10 3 > $MNAME/sys-iostat.log

    echo -n "vmstat..."
    vmstat 10 3 > $MNAME/sys-vmstat.log
    echo "Done."
fi

echo "Collecting MySQL data for host=$MHOST:"
echo -n "Mysql summary..."
$PT_BIN_PATH/pt-mysql-summary -- -h $MHOST -u $MUSER $CMDL_PASS > $MNAME/db-mysql-summary.log

echo -n "Live counters (20 seconds)..."
mysqladmin -h $MHOST -u $MUSER $CMDL_PASS -r -c 3 -i 10 extended-status > $MNAME/db-stats.log
echo "Done";

echo "Fetching Tables and Egines statistics:"

echo -n "1. Getting per-engine distribution..."
mysql -t -h $MHOST -u $MUSER $CMDL_PASS -e "SELECT engine, count(*) TABLES,  concat(round(sum(table_rows)/1000000,2),'M') rows, concat(round(sum(data_length)/(1024*1024*1024),2),'G') DATA, concat(round(sum(index_length)/(1024*1024*1024),2),'G') idx, concat(round(sum(data_length+index_length)/(1024*1024*1024),2),'G') total_size, round(sum(index_length)/sum(data_length),2) idxfrac FROM information_schema.TABLES WHERE table_schema NOT IN ('mysql', 'information_schema', 'performance_schema') GROUP BY engine ORDER BY sum(data_length+index_length) DESC LIMIT 10" > $MNAME/db-engines.log

echo -n "2. Getting TOP 10 largest tables by size..."
mysql -t -h $MHOST -u $MUSER $CMDL_PASS -e "SELECT concat(table_schema,'.',table_name), engine,  concat(round(table_rows/1000000,2),'M') rows, concat(round(data_length/(1024*1024*1024),2),'G') DATA, concat(round(index_length/(1024*1024*1024),2),'G') idx, concat(round((data_length+index_length)/(1024*1024*1024),2),'G') total_size, round(index_length/data_length,2) idxfrac FROM information_schema.TABLES ORDER BY data_length+index_length DESC LIMIT 10" > $MNAME/db-top-tables.log

echo -n "3. Getting tables size"
mysql -t -h $MHOST -u $MUSER $CMDL_PASS -e "SELECT concat(table_schema,'.',table_name), engine,  concat(round(table_rows/1000000,2),'M') rows, concat(round(data_length/(1024*1024*1024),2),'G') DATA, concat(round(index_length/(1024*1024*1024),2),'G') idx, concat(round((data_length+index_length)/(1024*1024*1024),2),'G') total_size, round(index_length/data_length,2) idxfrac FROM information_schema.TABLES WHERE table_schema NOT IN ('mysql', 'information_schema', 'performance_schema') ORDER BY table_schema ASC, data_length+index_length DESC" > $MNAME/db-all-tables.log

echo -n "4. Getting current InnoDB engine status..."
mysql -h $MHOST -u $MUSER $CMDL_PASS -e "SHOW ENGINE INNODB STATUS\G" > $MNAME/db-innodb.log

echo -n "5. Getting current process list..."
mysql -h $MHOST -u $MUSER $CMDL_PASS -e "SHOW PROCESSLIST\G" > $MNAME/db-processlist.log
echo "Done. Packing data.";

tar -zcvf $MNAME.tar.gz $MNAME/*

### Uncomment here to send archive to <email@address.com>:
#base64 $MNAME.tar.gz | mail -s "review $MNAME" <email@address.com>
