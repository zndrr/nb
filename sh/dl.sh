#!/bin/bash

# Author : zndrr
# Profile: https://github.com/zndrr
# Repo : nb
# License : MIT
# Created : 2023-09-14

# This is a lazy script to re-download file in to right directory every rollback.
# Uh ... on second thought, it grew a fair bit ...

say() { local msg="$1"; printf '%b\n' "${msg}"; }
lB() { printf '\n'; }

gAuthor="zndrr"
gRepo="nb"
gBranch="Upload-v1"
#gBranch="master"
gPath="${gRepo}-${gBranch}"
fExt=".zip"

gSubPath="sh"

fName="${gBranch}${fExt}"
URLD="https://github.com/${gAuthor}/${gRepo}/archive/refs/heads/${fName}"

rDir="/root"
archPath="${rDir}/${gPath}/${gSubPath}"

testScript="nb_inst.sh"
delPattern="WILL_YOU_CONTINUE"

#####

clear

lB
say "Repo and Branch : ${gPath}"
say "Branth Fullpath : ${gSubPath}"
say "Root dir : ${rDir}"
say "Download URL : ${URLD}"
say "Archive path : ${archPath}/${fName}"

lB; lB
sleep 1

mkdir -p "${rDir}"

if ! [ $(pwd) = $rDir ]; then
  say "Moving in to ${rDir}"
  cd $rDir
fi

if [ -e "${fName}" ]; then
  say "File looks to exist already. Download not required ..."
elif wget --spider "${URLD}" 2>/dev/null; then
  say "File found ..."
  sleep 1; lB
  say "Downloading ..."
  sleep 1; lB
  wget -q --show-progress "${URLD}" -P "${rDir}/" --no-check-certificate
  say "File is available in $(pwd)"
else
  say "File not found ..."
  exit 1
fi

say "Installing unzip ..."
  apt install -y unzip
  sleep 1

say "Extracting zip ..."
  unzip ${fName}
  find ${archPath} -name "*.*" -exec mv '{}' ${rDir} \;
  rm -r ${gPath}
say "... Extracted!"

## This allows you to execute the script from this one. Timesaver!"
if [ -e "${testScript}" ]; then
  say "Removing '${delPattern}' from '${testScript}"
    sed -i "s|'${delPattern}'||g" ${testScript}
  say "Warning, remember not to overwrite your main script with the testing version!"
    sleep 1
  say "Executing script ..."
    sleep 2
    bash ${testScript}
  say "... done!"
fi
