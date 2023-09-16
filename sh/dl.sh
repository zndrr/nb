#!/bin/bash

# Author : zndrr
# Profile: https://github.com/zndrr
# Repo : nb
# License : MIT
# Created : 2023-09-14

startTime=$(date +%s)

# This is a lazy script to re-download file in to right directory every rollback.
# Uh ... on second thought, it grew a fair bit ...
# Made on Ubuntu in bash (obviously)

say() { local msg="$1"; printf '%b\n' "${msg}"; }
lB() { printf '\n'; }

#################################################

gAuthor="zndrr"
gRepo="nb"

gBranch="Upload-v1"
#gBranch="master"

gPath="${gRepo}-${gBranch}"
fExt=".zip"

gSubPath="sh"

#################################################

fName="${gBranch}${fExt}"
urlD="https://github.com/${gAuthor}/${gRepo}/archive/refs/heads/${fName}"

rDir="/root"
archPath="${rDir}/${gPath}/${gSubPath}"

# This is to remove patterns in the testing script file (eg programmed delays or interactives)
testScript="nb_inst.sh"

delPattern="WILL_YOU_CONTINUE"
swapPattern=""

delPattern2="WILL_YOU_CONTINUE"
swapPattern2=""

#################################################

clear

lB; say "Some details below derived from defined variables:"; lB
say "Repo and Branch : ${gPath}"
say "Branth Fullpath : ${gSubPath}"
say "Root dir : ${rDir}"
say "Download URL : ${urlD}"
say "Archive path : ${archPath}/${fName}"

sleep 1; lB; lB

mkdir -p "${rDir}"

if [ ! $(pwd) = "${rDir}" ]; then
  say "Moving in to ${rDir}"
  cd $rDir
fi

if wget --spider "${urlD}" 2>/dev/null; then
  say "File found ..."
  sleep 1; lB
  if [ -e "${fName}" ]; then
    say "File looks to exist already. Deleting existing ..."
    rm "${fName}"
  fi
  say "Downloading ..."
  sleep 1; lB
  wget -q --show-progress "${urlD}" -P "${rDir}/" --no-check-certificate
  say "File is available in $(pwd)"
else
  say "File not found ..."
  exit 1
fi


## Uncomment this to install dependency
#say "Installing unzip ..."
#  apt update
#  apt install -y unzip
#  sleep 1

say "Extracting archive file to specified path ..."
  unzip -o "${fName}"
  find "${archPath}" -name "*.*" -exec mv '{}' ${rDir} \;
  rm -r ${gPath}
  rm "${fName}"
say "... Extracted!"; sleep 0.5

## This allows you to execute the testing script from this one. Timesaver!"
## Works by copying the file and modifying that, then deleting after.
if [ -e "${testScript}" ]; then
  #say "Removing pattern '${delPattern}' from '${testScript}"
  say "Removing pattern '${delPattern2}' from '${testScript}'"
  say "Cloning script to perform action. Original will be preserved."
    cp ${testScript} "temp.${testScript}"; sleep 0.5
    #sed -i "s|$delPattern||g" "temp.${testScript}"; sleep 0.5
    sed -i "s|$delPattern2|$swapPattern2|g" "temp.${testScript}"; sleep 0.5
  say "Executing script ..."
    sleep 2
    bash "temp.${testScript}"
  say "... done!"; sleep 1
  say "Cleaning up modified script."
  rm "temp.${testScript}"
fi
lB; lB

endTime=$(date +%s)
say "Script completed in $(( endTime - startTime )) seconds!"
sleep 3
lB; lB
