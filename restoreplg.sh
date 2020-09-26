#!/bin/bash

if [ -z "$1" ]; then
        echo "Need output filename, with .tar.gz"
        exit 1
fi

if [ -z "$2" ]; then
        l4d2root="$(pwd)/Steam/l4d2"
else
	l4d2root="$2"
fi

echo "Archieve File: $targz"
echo "left4dead2 folder path: $l4d2root"
tar --keep-directory-symlink -zxvf "$1" -C "$l4d2root"
