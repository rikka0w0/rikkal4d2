# Debian 7:
## Edit vi /etc/apt/sources.list:
Vim command, save and quit: `:wq`. File content:
```
deb http://archive.debian.org/debian/ wheezy main
deb http://archive.debian.org/debian-security/ wheezy/updates main
```
Fix apt-get (require sudo if using non-root user):
```
apt-get update
apt-get -o Acquire::Check-Valid-Until=false update
apt-get update
apt-get install debian-archive-keyring
```

# Create a non-root user for srcds:
`useradd -m l4d2`
Create a bash script (sul4d2.sh) for a quick swiching to that user:
```
cd /home/l4d2
sudo -u l4d2 bash
```

# Setup SteamCMD and srcds:
```
sudo apt-get update
sudo apt-get install -y sudo lib32gcc1 nano screen wget
sudo apt-get install -y --reinstall ca-certificates

mkdir Steam
cd Steam

wget http://media.steampowered.com/installer/steamcmd_linux.tar.gz
tar -xvzf steamcmd_linux.tar.gz
rm steamcmd_linux.tar.gz
```

# Install or update l4d2:
ul4d2.sh:
```
cd Steam
./steamcmd.sh +login anonymous +force_install_dir "l4d2" +app_update 222860 validate +quit
```

# Install addons:
```
rm -rfv Steam/l4d2/left4dead2/addons Steam/l4d2/left4dead2/cfg
ln -s addons Steam/l4d2/left4dead2/addons
ln -s cfg Steam/l4d2/left4dead2/cfg
```

# Start l4d2:
sl4d2.sh
```
cd Steam/l4d2
./srcds_run -game left4dead2 -port 27015 -insecure -num_edicts 8191 +ip 0.0.0.0 +maxplayers 8 +map c5m1_waterfront +allow_all_bot_survivor_team 1 +sv_gametypes coop
```