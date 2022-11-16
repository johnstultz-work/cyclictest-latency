#!/bin/bash
# Copyright 2022 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# This test expects iperf to be installed and binaries for cyclictest
# and speedtest-cli to be in the directory from where its run.

TEST_TIME_SEC=60
TMP_PATH=/tmp/
while getopts 't:p:h' opt; do
	case "$opt" in
		t)
			TEST_TIME_SEC=$OPTARG
			;;
		p)
			TMP_PATH=$OPTARG
			;;
		h)
			echo "Usage: $0 [-h][-t <seconds>][-p <tmp path>]"
			;;
		?)
			echo "Usage: $0 [-h][-t <seconds>][-p <tmp path>]"
			;;

	esac
done


NUM_PROC=`nproc`
TEST_RUNNING=./TEST.RUNNING.DELME

function start_cyclictest {
	./cyclictest -t -p 99 -D $TEST_TIME_SEC -q -i 1000
}

function start_iperf {
	iperf -s -t 5 > /dev/null &
	iperf -c localhost -u -b 10g -t $TEST_TIME_SEC -i 1 -P $NUM_PROC > /dev/null
#	iperf -c iperf.he.net -u -b 10g -t $TEST_TIME_SEC -i 1 -P $NUM_PROC > /dev/null
#	iperf -c iperf.he.net -u -b 100M -t $TEST_TIME_SEC -i 1 -P 2 > /dev/null
	echo "iperf done"
}

function start_speedtest {
	return

	while [ -f "$TEST_RUNNING" ]
	do
		./speedtest-cli --secure
	done
	echo "speedtest done"
}


function start_copy_noise {

	while [ -f "$TEST_RUNNING" ]
	do
		mkdir -p $TMP_PATH/A/
		mkdir -p $TMP_PATH/B/
		dd if=/dev/zero  of=$TMP_PATH/A/bigfile.delme bs=1M count=200 &> /dev/null
		sync
		cp $TMP_PATH/A/* $TMP_PATH/B/
		rm $TMP_PATH/A/*
		sync

		cp $TMP_PATH/B/* $TMP_PATH/A/
		rm $TMP_PATH/B/*
		sync

		rm $TMP_PATH/A/*
		rmdir $TMP_PATH/A $TMP_PATH/B
		sync
	done
	echo "copy noise done!"
}


function start_dd_noise {

	while [ -f "$TEST_RUNNING" ]
	do
		file="$TMP_PATH/myci.dd.file"
		for i in $(seq $NUM_PROC)
		do
			dd if=/dev/zero  of=$file.$i bs=1M count=128 &> /dev/null &
		done
		wait
		sync
		rm -f $file*
	done
	echo "dd noise done"
}

rm -f $TEST_RUNNING

echo "Running for $TEST_TIME_SEC seconds"
touch $TEST_RUNNING
start_iperf & 
IPERF_PID=$!
start_speedtest &
SPEEDTEST_PID=$!
start_copy_noise &
COPY_PID=$!
start_dd_noise &
DD_PID=$!

start_cyclictest
rm -f $TEST_RUNNING

wait $IPERF_PID
wait $SPEEDTEST_PID
wait $COPY_PID
wait $DD_PID
