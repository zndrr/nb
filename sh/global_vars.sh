#!/bin/bash

# THIS IS INTENDED AS AN ENV FILE ONLY
# DEFINITIONS ONLY, NO EXECUTION

BIG_NAME_IS_BIG() {
  cat <<"EOF"
8888888888P 888b    888 8888888b.  8888888b.  8888888b.  
      d88P  8888b   888 888  "Y88b 888   Y88b 888   Y88b 
     d88P   88888b  888 888    888 888    888 888    888 
    d88P    888Y88b 888 888    888 888   d88P 888   d88P 
   d88P     888 Y88b888 888    888 8888888P"  8888888P"  
  d88P      888  Y88888 888    888 888 T88b   888 T88b   
 d88P       888   Y8888 888  .d88P 888  T88b  888  T88b  
d8888888888 888    Y888 8888888P"  888   T88b 888   T88b 
EOF
}


##### Global env definitions

## Set colour variables
RED=$(tput setaf 1)
REDB=$(tput bold setaf 1)
GREEN=$(tput setaf 2)
YEL=$(tput setaf 3)
YELB=$(tput bold setaf 3)
BLUE=$(tput setaf 4)
BLUU=$(tput smul setaf 4)
CYAN=$(tput setaf 6)
CYANB=$(tput bold setaf 6)
CLR=$(tput sgr0)


## Terminal text colouration for readability
txt_norm() { local msg="$1"; printf '%b\n' "${msg}"; }
txt_nindent() { local msg="$1"; printf '%b\n' "  ${msg}"; }

txt_info() { local msg="$1"; printf '%b\n' "${CYAN}${msg}${CLR}"; }
txt_ok() { local msg="$1"; printf '%b\n' "${GREEN} ✓ ${msg}${CLR}"; }
txt_warn() { local msg="$1"; printf '\n%b\n' "${YELB} ! ${msg}${CLR}"; }
txt_err() { local msg="$1"; printf '\n%b\n' "${REDB} ✗ ${msg}${CLR}"; }

txt_header() { local msg="$1"; printf '\n%b\n' "${CYANB}${msg}${CLR}"; SL1; }
txt_url() { local msg="$1"; printf '%b\n' "${BLUU}${msg}${CLR}"; }


## Delay, carriage returns, spacing
SL0() { sleep 0.5; }
SL1() { sleep 1; }
SL2() { sleep 2; }
CR1() { printf '\n'; }
CR2() { printf '\n\n'; }
SP1() { printf " ";}
SP2() { printf "  ";}

## Graceful exit on interrupt
trap STAGE_LEFT SIGINT
STAGE_LEFT() {
  CR1
  txt_warn "Ctrl+C or Interrupt detected ... ending script."
  exit
}

## Fancy animated output
DOT() { printf "."; }
DOTZ() { SL0; DOT; SL0; DOT; SL0; DOT; SL0; DOT; SL0; }

START_OVER() {
  printf '\n%b' "Restarting script from beginning"; DOTZ; CR1; clear
  exec bash "$0"
}

GAME_OVER() {
  printf '\n\n%b' "Ending the script"; DOTZ; CR1;
  exit 1
}

WILL_YOU_CONTINUE() {
while true; do
  txt_norm "Do you want to continue?"
  SL0
  read -p "(c)ontinue | (r)estart | (q)uit : " -r -n 1 CHOICE
  if [[ $CHOICE =~ ^[Cc]$ ]]; then
    SL0
    break
  elif [[ $CHOICE =~ ^[Rr]$ ]]; then
    SL0
    START_OVER
    exec bash "$0"
  elif [[ $CHOICE =~ ^[Qq]$ ]]; then
    SL0
    GAME_OVER
  else
    SL0
  fi
  txt_warn "Not a valid choice. Please select again ..."
  SL1
  continue
done
CR1
txt_ok "Continuing ..."
}

ROOT_CHECK() {
txt_info "Checking root privileges ..."
SL2
if ! [ "$(whoami)" = root ]; then
  txt_err "Please run this script as root or using sudo ..."
  GAME_OVER
else
  txt_ok "Root privileges confirmed. Continuing ..."
fi
}
