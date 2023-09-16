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

## NEW : Terminal text colouration for readability
t_norm() { local msg="$1"; printf '%b\n' "${msg}"; }
t_info() { local msg="$1"; printf '%b\n' "${CYAN}${msg}${CLR}"; }
t_ok() { local msg="$1"; printf '%b\n' "${GREEN} ✓ ${msg}${CLR}"; }
t_warn() { local msg="$1"; printf '%b\n' "${YELB} ! ${msg}${CLR}"; }
t_err() { local msg="$1"; printf '%b\n' "${REDB} ✗ ${msg}${CLR}"; }
t_head() { local msg="$1"; printf '\n%b\n' "${CYANB}${msg}${CLR}"; SL1; }
t_url() { local msg="$1"; printf '%b\n' "${BLUU}${msg}${CLR}"; }

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
  t_warn "Ctrl+C or Interrupt detected ... ending script."
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
  t_norm "Do you want to continue?"
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
  t_warn "Not a valid choice. Please select again ..."
  SL1
  continue
done
CR1
t_ok "Continuing ..."
}

ROOT_CHECK() {
t_info "Checking root privileges ..."
SL2
if ! [ "$(whoami)" = root ]; then
  t_err "Please run this script as root or using sudo ..."
  GAME_OVER
else
  t_ok "Root privileges confirmed. Continuing ..."
fi
}


      #=# PLACEHOLDER REMINDER
      # change some or all to while loops with local var counters

## Check functions. Some might not work on CentOS, but don't know yet.
CHECK_PKG_MGR() {
local DSTRO=0
t_info "Checking package manager..."
SL2
if [[ $(command -v apt) ]]; then
  PMGR="apt"
  DSTRO="Debian/Ubuntu"
elif [[ $(command -v yum) ]]; then
  PMGR="yum"
  DSTRO="CentOS"
        #=# PLACEHOLDER REMINDER
        # Test with CentOS release to validate.
  t_warn "Script hasn't been tested against CentOS !"
  t_warn "Run at your own peril !"
  WILL_YOU_CONTINUE
else
  t_err "Package manager not APT(Debian/Ubuntu) or YUM(RHEL/CentOS)"
  t_err "Script doesn't support other types ..."
  GAME_OVER
fi
t_ok "Package manager identified as ${PMGR} (${DSTRO})"
PMUPD="${PMGR} update"
PMGET="${PMGR} install -y"
SL0
}

      #=# PLACEHOLDER REMINDER
      # Incomplete. Needs prompts for install.
CHECK_PKG() {
local list=($@)
for service in "${list[@]}"; do
if [ ! $(command -v $service ) ]; then
  local missing+=($service)
fi
done
t_warn "The following aren't installed:"
t_info "  ${missing[@]}"; SL2

t_err "Reminder"
t_err "Prompt to install goes here !!"
t_err "Reminder"

for install in ${missing[@]}; do
  $PMGET $install
  t_warn "Debug CHECK_PKG install"
done
}



CHECK_START() {
if [ ! $(systemctl is-active "$1" ) > /dev/null ]; then
  t_err "Process '$1' doesn't appear to have started!"
fi
}

CHECK_STOP() {
if [ $(systemctl is-active "$1" ) > /dev/null ]; then
  t_err "Process '$1' doesn't appear to have stopped!"
fi
}

CHECK_URL() {
if curl -sSfkL -m 3 "$1" -o /dev/null; then 
  t_ok "Web Server ' $1 ' is reachable."
fi
}



      #=# PLACEHOLDER : NEEDS DELETION
PKG_MGR_CHECK() {
local DSTRO=0
t_info "Checking package manager..."
SL2
if [[ $(which apt) ]]; then
  PMGR="apt"
  DSTRO="Debian/Ubuntu"
elif [[ $(which yum) ]]; then
  PMGR="yum"
  DSTRO="CentOS"
        #=# PLACEHOLDER REMINDER
        # Test with CentOS release to validate.
  t_warn "Script hasn't been tested against CentOS !"
  t_warn "Run at your own peril !"
  WILL_YOU_CONTINUE
else
  t_err "Package manager not APT(Debian/Ubuntu) or YUM(RHEL/CentOS)"
  t_err "Script doesn't support other types ..."
  GAME_OVER
fi
t_ok "Package manager identified as ${PMGR} (${DSTRO})"
PMUPD="${PMGR} update"
PMGET="${PMGR} install -y"
SL0
}

# Compare release versions in semantic format (ref xxvix).
SW_VER() {
  printf '%b\n' "$1" | awk -F. '{ printf("%d%03d%03d\n", $1,$2,$3,$4); }'
}


