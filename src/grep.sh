#!/bin/sh

cd `dirname $0`

grep -a $@ *.inc *.asm | nkf -w
