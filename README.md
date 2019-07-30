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
Swich to that user:
```
cd /home/l4d2
su l4d2
```
Then switch to user "l4d2".

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

# Use the plugin pack:
Using user "l4d2", in home directory:
```
ln -s rikkal4d2/sl4d2.sh sl4d2.sh
ln -s rikkal4d2/ul4d2.sh ul4d2.sh
chmod +x sl4d2.sh ul4d2.sh
```

# Install or update l4d2:
ul4d2.sh:

# Install addons:
Using user "l4d2", in home directory:
```
rm -rfv Steam/l4d2/left4dead2/addons Steam/l4d2/left4dead2/cfg
ln -s ~/rikkal4d2/addons Steam/l4d2/left4dead2/addons
ln -s ~/rikkal4d2/cfg Steam/l4d2/left4dead2/cfg
```

# Start l4d2:
sl4d2.sh