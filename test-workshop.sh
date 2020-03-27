#!/bin/bash
set -e

echo 'Please enter the Hydra name for the test'
read hydraname

linuxsut="${hydraname}nix0.classroom.puppet.com"
winsut="${hydraname}win0.classroom.puppet.com"

#### PREP ####

if ! [ -d "Boltdir" ]; then
  mkdir Boltdir
else
  rm -rf Boltdir/*
fi

#### END PREP ####

if ! [ -f "./student.pem" ]; then
  echo 'No student pem file available. Please download the student.pem'
  echo 'Future versions may allow an SE to test with a standard student.pem'
  exit 1
fi

# Test 1 - Bolt Commands
echo -e "\n########## Performing Test 1 - Basic Bolt Commands ##########\n"
sleep 1

bolt command run 'ping 8.8.8.8 -c2' --targets $linuxsut --user centos --private-key $(pwd)/student.pem --transport ssh --no-host-key-check

bolt command run 'ping 8.8.8.8 -n 2' --targets $winsut --user Administrator --password Puppetlabs! --transport winrm --no-ssl

# Test 2 - Bolt.yaml
echo -e "\n########## Performing Test 2 - Bolt.yaml ##########\n"
sleep 1

cat <<- 'EOF' > Boltdir/bolt.yaml
---
ssh:
  host-key-check: false
winrm:
  ssl: false
EOF

bolt command run 'ping 8.8.8.8 -c2' --targets $linuxsut --user centos --private-key $(pwd)/student.pem

bolt command run 'ping 8.8.8.8 -n 2' --targets $winsut --user Administrator --password Puppetlabs! --transport winrm

# Test 3 - Gather Inventory.yaml
# Rather than sed and edit in place (Unix Style). We'll sed and move to support OSX's default POSIX-style Sed
echo -e "\n########## Performing Test 3 - Inventory.yaml ##########\n"
sleep 1

wget "http://bit.ly/${hydraname}boltinventory" -O Boltdir/inventory_stage.yaml
sed 's/<X>/0/g' ./Boltdir/inventory_stage.yaml > Boltdir/inventory.yaml


# Test 4 - Validate Inventory.yaml
echo -e "\n########## Performing Test 4 - Inventory.yaml ##########\n"
sleep 1

bolt command run 'ping 8.8.8.8 -c2' --targets linux
bolt command run 'ping 8.8.8.8 -n 2' --targets windows
bolt command run 'hostname' --targets linux,windows

# Test 5 - Run a Script
echo -e "\n########## Performing Test 5 - Script Runs ##########\n"
sleep 1

wget "http://bit.ly/vbolttimesync" -O timesync.ps1
bolt script run timesync.ps1 --targets windows

# Test 6 - Transform Script into Task
echo -e "\n########## Performing Test 6 - Task Run ##########\n"
sleep 1

mkdir -p Boltdir/site/tools/tasks
mv timesync.ps1 Boltdir/site/tools/tasks/
bolt task show
bolt task run tools::timesync --targets windows

# Test 7 - Parameterizing Tasks
echo -e "\n########## Performing Test 7 - Parameterization ##########\n"
sleep 1

wget "http://bit.ly/vbolttimesyncjson" -O Boltdir/site/tools/tasks/timesync.json
wget "http://bit.ly/vbolttimesyncrestart" -O Boltdir/site/tools/tasks/timesync.ps1

bolt task show
bolt task show tools::timesync
bolt task run tools::timesync -t windows restart=true

# Test 8 - Build a Plan
echo -e "\n########## Performing Test 8 - Build a Plan ##########\n"
sleep 1

mkdir Boltdir/site/tools/plans
wget "http://bit.ly/vbolttimesyncplan" -O Boltdir/site/tools/plans/timesync.pp
bolt plan show
bolt plan show tools::timesync
bolt plan run tools::timesync --targets windows

# Test 9 - Apply Puppet Code
echo -e "\n########## Performing Test 9 - Puppet Apply ---NOTE: THIS SHOULD FAIL--- ##########\n"
sleep 1

wget "http://bit.ly/timesyncmanifest" -O timesync_windows.pp
bolt apply timesync_windows.pp --targets windows || ret=0

# Test 10 - Dependencies
echo -e "\n########## Performing Test 10 - Dependencies ##########\n"
sleep 1

cat <<- 'EOF' > Boltdir/Puppetfile
# Modules from the Puppet Forge.
mod 'puppetlabs-stdlib',    '5.1.0'
mod 'puppetlabs-registry',  '2.1.0'
mod 'ncorrare-windowstime', '0.4.3'
mod 'puppetlabs-ntp',       '7.3.0'
EOF
bolt puppetfile install
bolt apply timesync_windows.pp --targets windows

# Test 11 - Cross Platform Design
echo -e "\n########## Performing Test 11- Multiplatform ##########\n"
sleep 1

wget "http://bit.ly/vboltmultiplatform" -O Boltdir/site/tools/plans/timesync_code.pp
bolt plan run tools::timesync_code --targets windows,linux