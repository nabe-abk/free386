#!/bin/sh

for f in *.ASM; do
	base=`basename "$f" .ASM`
	echo nasm -f bin -o "$base.COM" "$f"
	     nasm -f bin -o "$base.COM" "$f"
done

