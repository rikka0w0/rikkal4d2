#!/bin/bash

if [ -z "$1" ]; then
        echo "Need output filename"
        exit 1
fi

targz="$1.tar.gz"

if [ -z "$2" ]; then
        l4d2root="$(pwd)/Steam/l4d2/left4dead2"
else
	l4d2root="$2"
fi

echo "Output File: $targz"
echo "left4dead2 folder path: $l4d2root"

# Create a temp folder
mkdir "$(pwd)/$1.tmp"
mkdir "$(pwd)/$1.tmp/left4dead2"

# Copy plugins
addons="$(pwd)/$1.tmp/left4dead2/addons"
mkdir "$addons"
cp -r "$l4d2root/addons/l4dtoolz" "$addons"
cp -r "$l4d2root/addons/metamod" "$addons"
cp "$l4d2root/addons/metamod.vdf" "$addons"
cp -r "$l4d2root/addons/sourcemod" "$addons"
# Exclude server name 
mv "$addons/sourcemod/configs/hostname/hostname.txt" "$(pwd)/$1.hostname.txt"
mv "$addons/sourcemod/configs/advertisements.txt" "$(pwd)/$1.advertisements.txt"

# Copy configurations
cfg="$(pwd)/$1.tmp/left4dead2/cfg"
mkdir "$cfg"
cp "$l4d2root/cfg/server.cfg" "$cfg"
cp -r "$l4d2root/cfg/sourcemod" "$cfg"

# Copy motd and server provider message
cp "$l4d2root/motd.txt" "$(pwd)/$1.tmp/left4dead2"

# Create archieve
echo "Creating archieve"
cd "$(pwd)/$1.tmp"
tar -zcf "../$targz" *
cd ..
echo "Deleting temp files"
rm -r "$(pwd)/$1.tmp"
echo "Done"
