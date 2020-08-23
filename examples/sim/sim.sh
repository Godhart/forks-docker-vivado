#!/bin/bash

OUT_DIR=/home/user/output
WORKSPACE_DIR=/home/user/workspace

source /tools/Xilinx/Vivado/2020.1/settings64.sh

mkdir -p $OUT_DIR
cd $OUT_DIR

xvlog --sv --incr --relax $WORKSPACE_DIR/hello.v
xelab -R --timescale 1ps/1ps -O3 hello
