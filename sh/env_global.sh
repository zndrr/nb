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
MAGENTABL=$(tput smso setaf 125)
CLR=$(tput sgr0)

## NEW : Terminal text colouration for readability
t_norm() { local msg="$1"; printf '%b\n' "${msg}"; }
t_info() { local msg="$1"; printf '%b\n' "${CYAN}${msg}${CLR}"; }
t_ok() { local msg="$1"; printf '%b\n' "${GREEN} ✓ ${msg}${CLR}"; }
t_warn() { local msg="$1"; printf '%b\n' "${YELB} ! ${msg}${CLR}"; }
t_err() { local msg="$1"; printf '%b\n' "${REDB} ✗ ${msg}${CLR}"; }
t_head() { local msg="$1"; printf '\n%b\n' "${CYANB}${msg}${CLR}"; SL1; }
t_url() { local msg="$1"; printf '%b\n' "${BLUU}${msg}${CLR}"; }
t_db() { local msg="$1"; printf '%b\n' "${MAGENTABL}DEBUG: ${msg}${CLR}"; }

## Delay, carriage returns, spacing

# You can create a file called .NB_FAST in the script root. Good for repeat use.
if [ -e .NB_FAST ] || [ SKIP=yes ]; then
  SL0() { sleep 0.1; }
  SL1() { sleep 0.2; }
  SL2() { sleep 0.3; }
else
  SL0() { sleep 0.5; }
  SL1() { sleep 1; }
  SL2() { sleep 2; }
fi
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
# You can create a file called .NB_FAST in the script root. Good for repeat use.
if [ -e .NB_FAST ] || [ SKIP=yes ]; then
  t_warn "Auto-skipping continue prompt (implied continue) ..."
  SL1; CR1
else
  t_norm "Do you want to continue?"
  while true; do
    read -p "(c)ontinue | (r)estart | (q)uit : " -r -n 1 CHOICE
    case $CHOICE in
      c|C)
        break;;
      r|R)
        START_OVER ;;
      q|Q)
        GAME_OVER ;;
      *)
        t_warn "Not a valid choice. Please select again ..."; CR1
    esac
  done
  CR1
  t_ok "Continuing ..."
#fi
}

CHECK_ROOT() {
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
SL0
}

## Quiet commands, no redirection
PMUPD(){ ${PMGR} update; }
PMGET(){ ${PMGR} install -qq -y $1; }
PMREM(){ ${PMGR} remove -qq -y $1; }
#PMREM(){ ${PMGR} purge -qq -y $1; }

## These are the normalish output commands, redirection
#! PMUPD(){ ${PMGR} update &> .nb_apt_update.log; }
#! PMGET(){ ${PMGR} install -y $1 &> .nb_apt_install.log;; }
#! PMREM(){ ${PMGR} remove -y $1 &> .nb_apt_remove.log; }
#! #PMREM(){ ${PMGR} purge -y $1 &> .nb_apt_remove.log; } # uncomment to change remove > purge (more comprehensive)

      #=# PLACEHOLDER REMINDER
      # Incomplete. Needs prompts for install.
      # apt-specific ; needs a yum fallback
CHECK_PKG() {
# NOTE : need to seriously evaluate whether this is worth not just installing packages and relying on the package managers.
local list=($@)
if [[ $PMGR = apt ]]; then
  for service in ${list[@]}; do
    if ! apt-mark showinstall | grep -e "^$service$" &> /dev/null; then
      local missing+=($service)
    elif apt-mark showinstall | grep -e "^$service$" &> /dev/null; then
      local found+=($service)
    else
      # Perhaps I'll do something more flexible here.
      t_err "Undetermined fate. Cannot proceed ..."
      GAME_OVER
    fi
  done
  if [ ${found} ]; then
      t_ok "The following are installed:"
      t_norm "  ${found[*]}";
  fi
  if [ ${missing} ]; then
    t_err "The following aren't installed:"
    t_norm "  ${missing[*]}";
    # PLACEHOLDER REMINDER give fn prompt, maybe a while loop just in case
    PMGET "${missing[*]}"
  fi
elif [[ $PMGR = yum ]]; then
  # This is a fallback since apt is not CentOS and so that detection won't likely work.
  t_info "Installing required packages ..."
  PMGET "${list[*]}"
  SL1
  t_ok " ... done" 
else
  t_err "Not sure how you got this far, but here's an error for your troubles !"
  GAME_OVER
fi
}

      #=# PLACEHOLDER REMINDER
      # make this more robust like a loop
CHECK_START() {
SL2
if [ ! $(systemctl is-active "$1" ) > /dev/null ]; then
  t_err "Process '$1' doesn't appear to have started!"
fi
}

CHECK_STOP() {
SL2
if [ $(systemctl is-active "$1" ) > /dev/null ]; then
  t_err "Process '$1' doesn't appear to have stopped!"
fi
}

CHECK_URL() {
SL2
if curl -sSfkL -m 3 "$1" -o /dev/null; then 
  t_ok "Web Server ' $1 ' is reachable."
fi
}

# Compare release versions in semantic format (ref xxvix).
SW_VER() {
  printf '%b\n' "$1" | awk -F. '{ printf("%d%03d%03d\n", $1,$2,$3,$4); }'
}


