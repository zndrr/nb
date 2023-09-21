#!/bin/bash

printf '\n%b\n' "This script will add some shortcuts to a new file named .bash_netbox and load it in to .bashrc"
sleep 1
printf '\n%b\n' "Creating file ${HOME}/.bash_netbox ..."
sleep 1
if [[ ! -e ~/.bash_netbox ]]; then
  cat <<"EOF" >> ~/.bash_netbox
nbv() { source /opt/netbox/venv/bin/activate; }
nbvd() { deactivate; }
nbmg() { userIn=$@; source /opt/netbox/venv/bin/activate; python3 /opt/netbox/netbox/manage.py $userIn; }
nbs() { source /opt/netbox/venv/bin/activate; python3 /opt/netbox/netbox/manage.py nbshell; }
nbcmd() {
printf '\n%b\n\n' "List of Netbox shorcuts here:"
printf '%b\n' " nbv - Netbox Python3 venv"
printf '%b\n' " nbd - Deactivate Netbox venv"
printf '%b\n' "nbmg - Netbox manage.py (in venv)"
printf '%b\n' " nbs - Netbox nbshell"
}
EOF
printf '%b\n\n' "... done!"
else
  printf '\n%b\n' "... Nothing to do; ${HOME}/.bash_netbox already exists."
fi

printf '%b\n' "Adding .bash_netbox source to ~/.bashrc ..."
lineNbSrc="if [ -f ~/.bash_netbox ]; then source ~/.bash_netbox; fi"

if ! grep -qF -- "${lineNbSrc}" ~/.bashrc; then
  printf '%b' "${lineNbSrc}" >> ~/.bashrc
  printf '%b\b\n' "... done!"
else
  printf '%b\n\n' "... nothing to do; .bash_netbox already source in .bashrc"
fi

printf '%b\n' "To load .bash_netbox, re-login to bash or run this line ..."
printf '%b\n\n' "  source ~/.bash_netbox"
