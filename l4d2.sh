#!/bin/bash

echo "Usage:"
echo "Use \"update\" as argument to update/install l4d2 without start the server."
echo "Otherwise, this script starts the l4d2 server (if installed)."
echo

# Get the directory containing this script
SOURCE=${BASH_SOURCE[0]}
# resolve $SOURCE until the file is no longer a symlink
while [ -L "$SOURCE" ]; do
	SCRIPT_DIR=$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )
	SOURCE=$(readlink "$SOURCE")
	# if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
	[[ $SOURCE != /* ]] && SOURCE=$SCRIPT_DIR/$SOURCE
done
SCRIPT_DIR=$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )

# Get the Steam installation path
STEAM_PATH_TXT="$SCRIPT_DIR/steam_path.txt"
if [[ -f "$STEAM_PATH_TXT" ]]; then
	STEAM_PATH=$(head -n 1 "$STEAM_PATH_TXT")
else
	# Default Steam location, relative to this script
	STEAM_PATH=$(realpath "$SCRIPT_DIR/../Steam")
fi

echo "Steam is located at: $STEAM_PATH"

UPDATE_SCRIPT=$SCRIPT_DIR/l4d2.txt
UPDATE_ARGS="-steam_dir $STEAM_PATH -steamcmd_script $UPDATE_SCRIPT"
echo $UPDATE_ARGS

if [[ "$1" == "update" ]]; then
	# Update the l4d2 server
	cd $STEAM_PATH
	echo "Updating the server..."
	echo
	./steamcmd.sh +runscript $UPDATE_SCRIPT
else
	# Start the l4d2 server
	cd $STEAM_PATH/l4d2
	echo "Starting the server..."
	echo
	./srcds_run -game left4dead2 -port 27015 -insecure -num_edicts 8191 +ip 0.0.0.0 +maxplayers 8 +map c5m1_waterfront +allow_all_bot_survivor_team 1 +sv_gametypes coop -autoupdate $UPDATE_ARGS
fi
