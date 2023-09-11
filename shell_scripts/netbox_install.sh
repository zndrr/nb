#!/usr/bin/env bash

GREETINGS_TRAVELLER() {
  cat <<"EOF"
# # # # # # # # # # # # # # # # # # # # # # # # # #
#
# Author
#  GitHub user :
#  GitHub Profile :
#  Repo :
#  License : MIT
#
# This aims to install or upgrade Netbox instance.
#
# Review code and run at your own risk.
# No responsibility assumed.
#
# Git install not supported at this stage.
# For Git install, please follow guidance.
#
# https://github.com/netbox-community/
# https://docs.netbox.dev/en/stable/installation/
#
#
#  Created: 2023-07-09
#  Updated: 2023-07-12
#
#   Script created in Bash 5.1.16(1) on Ubuntu.
#   Tested against: Netbox v3.5.9 and v3.6.2
#
# # # # # # # # # # # # # # # # # # # # # # # # # #
EOF
}


#################################################################################################
# Set environment stuff.

# Set colour variables. Some may not be used, but shrug
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

# Defining terminal output formatting
txt_norm() { local msg="$1"; printf '%b\n' "${msg}"; }
txt_nindent() { local msg="$1"; printf '%b\n' "  ${msg}"; }

txt_info() { local msg="$1"; printf '%b\n' "${CYAN}${msg}${CLR}"; }
txt_ok() { local msg="$1"; printf '%b\n' "${GREEN} ✓ ${msg}${CLR}"; }
txt_warn() { local msg="$1"; printf '%b\n' "${YELB} ! ${msg}${CLR}"; }
txt_err() { local msg="$1"; printf '%b\n' "${REDB} ✗ ${msg}${CLR}"; }

txt_header() { local msg="$1"; printf '%b\n' "${CYANB}${msg}${CLR}"; }
txt_url() { local msg="$1"; printf '%b\n' "${BLUU}${msg}${CLR}"; }

# Path variables
ROOT=/opt
NBROOT=$ROOT/netbox
BKROOT=$ROOT/nb-backup

NBMEDIA=$NBROOT/netbox/media/
NBREPORTS=$NBROOT/netbox/reports/
NBSCRIPTS=$NBROOT/netbox/scripts/

# Variables to validate release version inputs etc.
# Check and update periodically as newer releases roll around.
REGEXVER="^[0-9].[0-9].[0-9]$"
MINOR1=3.6.0
MINOR2=3.5.0
MAJOR1=3.0.0

# URL variables for text output. Update if they change.
URLU="https://docs.netbox.dev/en/stable/installation/upgrading/"
URLN="https://docs.netbox.dev/en/stable/installation/"
URLR="https://github.com/netbox-community/netbox/releases/"
URLC="https://github.com/netbox-community/"

# Required packages for Netbox. Noted as of v3.6.2

PKG_MGR="apt install -y"
#PKG_MGR="yum install -y"
PKG_SCRIPT="wget tar"
PKG_PSQL="postgresql"
PKG_REDIS="redis-server"
PKG_NETBOX="python3 python3-pip python3-venv python3-dev build-essential libxml2-dev libxslt1-dev libffi-dev libpq-dev libssl-dev zlib1g-dev"
PKG_WWW="nginx"

# Graceful exit on interrupt
trap handleInt SIGINT

handleInt() {
  txt_warn "Ctrl+C or Interrupt detected ... ending script."
  exit
}

# Set functions for cleaner code

SL0() { sleep 0.5; }
SL1() { sleep 1; }
SL2() { sleep 2; }

DOTZ() { SL1; printf "."; SL1; printf "."; SL1; printf '%b\n' "."; }

START_OVER() {
  printf '\n%b' "Restarting script from beginning"; SL1; printf "."; SL1; printf "."; SL1; printf '%b\n' "."; clear
  exec bash "$0"
}

GAME_OVER() {
  printf '\n\n%b' "Ending the script"; SL1; printf "."; SL1; printf "."; SL1; printf '%b\n' "."
  exit 1
}

WILL_YOU_CONTINUE() {
while true; do
  txt_norm "Do you want to continue?"
  read -p "(c)ontinue | (r)estart | (q)uit : " -n 1 -r CHOICE
  if [[ $CHOICE =~ ^[Cc]$ ]]; then
    SL1
    break
  elif [[ $CHOICE =~ ^[Rr]$ ]]; then
    SL1
    echo
    START_OVER
    exec bash "$0"
  elif [[ $CHOICE =~ ^[Qq]$ ]]; then
    SL1
    GAME_OVER
  else
    SL1
    echo
  fi
  txt_warn "Not a valid choice. Please select again ..."
  SL1
  continue
done
echo
txt_ok "Continuing ..."
}


#################################################################################################
# Sanity checks for successful script execution

clear

# Check for sudo privileges. Exit if not.
txt_info "Checking root privileges ..."
SL2
if [ `whoami` != root ]; then
  txt_err "Please run this script as root or using sudo ..."
  GAME_OVER
else
  txt_ok "Root privileges confirmed. Continuing ..."
fi
SL1


# Check critical packages installed. Exit if not.

txt_info "Checking packages required for script ..."
SL2

for pkg in $PKG_SCRIPT; do
  command -v $pkg &>/dev/null
  if [[ $? != 0 ]]; then
    txt_warn "Package '$pkg' is not installed!"
    PKGMISSING=$(( PKGMISSING + 1 ))
    SL0
  fi
done

if [[ $PKGMISSING > 0 ]]; then
  txt_err "... Script cannot run without these packages."
  GAME_OVER
fi

txt_ok "Packages okay. Continuing ..."
SL1

#################################################################################################
# Make deterministic choice

txt_norm "Choose your install type:"
SL1
PS3="(1) Upgrade, (2) New, (3) Git, (4) Quit: "

select option in Upgrade New Git Quit
do
    case $option in
        Upgrade) 
            INSTALL=upgrade
            break;;
        New) 
            INSTALL=new
            break;;
        Git)
            INSTALL=git
            txt_err "Git install not supported yet. Try again..."
            SL1
            echo
            $txtreset;;
        Quit)
            GAME_OVER;;
        *)
            txt_warn "Invalid option '${REPLY}'. Try again..."
            SL1
            echo
            $txtreset;;
     esac
done
txt_info "Will proceed with ${INSTALL} install ..."

SL1

#################################################################################################
# Start script here

txt_header "+++ STAGE1 : DOWNLOADING NETBOX ARCHIVE FILE +++"

txt_info "Moving in to $ROOT directory ..."
mkdir -p $ROOT
cd $ROOT

SL2

## PLACEHOLDER REMINDER : COME BACK TO THIS
##
##  if ! [[ $OLDVER =~ $REGEXVER ]]; then
##    if [[ $ATTEMPTS > 1 ]]; then
##      txt_err "... Three incorrect attempts made."
##      GAME_OVER
##    fi
##    txt_err "Selection '${OLDVER}' format STILL not valid (eg 3.6.0). Try again ..."
##    ATTEMPTS=$(( ATTEMPTS +1 ))
##    SL1
##    continue

while true; do
  echo
  read -p "Please enter desired Netbox release (eg 3.6.0) and press Enter: " NEWVER
  URLD="https://github.com/netbox-community/netbox/archive/v${NEWVER}.tar.gz"
  if ! [[ $NEWVER =~ $REGEXVER ]]; then
    if [[ $ATTEMPTS > 1 ]]; then
      txt_err "... Too many incorrect attempts made."
      GAME_OVER
    fi
    txt_warn "Selection '${NEWVER}' not valid (eg 3.6.0). Try again ..."
    ATTEMPTS=$(( ATTEMPTS +1 ))
    SL1
    continue
  elif [ -e $ROOT/v$NEWVER.tar.gz ]; then
    txt_ok "File looks to exist already. Download not required ..."
    break
  elif ! [ -e $ROOT/v$NEWVER.tar.gz ]; then
    if [[ `echo "$NEWVER $MAJOR1" | awk '{print ($1 < $2)}'` == 1 ]]; then
      txt_err "Current selection (${NEWVER}) looks to be at least 1 major release older than (${MAJOR1}) !"
      txt_err "Selection too old! Select again ..."
      continue
    elif [[ `echo "$NEWVER $MINOR2" | awk '{print ($1 < $2)}'` == 1 ]]; then
      txt_warn "Current selection (${NEWVER}) looks to be at least 2 minor releases older than (${MINOR2}) !"
      txt_warn "Highly recommended to seek a newer release !"
    elif [[ `echo "$NEWVER $MINOR1" | awk '{print ($1 < $2)}'` == 1 ]]; then
      txt_warn "Current selection (${NEWVER}) looks to be at least 1 minor release older than (${MINOR1}) !"
    SL1
    fi
    txt_info "Checking availability ..."
    if wget --spider "${URLD}" 2>/dev/null; then
      txt_ok "Release v${NEWVER} found. Downloading ..."
      SL1
      wget -q --show-progress $URLD -P $ROOT/ --no-check-certificate
      SL1
      txt_ok "... Download complete!"
    else
      SL1
      txt_err "Netbox v${NEWVER} either doesn't exist or URL is unavailable ..."
      SL1
      echo
      txt_info "Check Releases here:"
      txt_url "${URLR}"
      echo
      if [[ $INSTALL = new ]]; then
        txt_info "Also refer to the below for new install process ..."
        txt_url "${URLN}"
      elif [[ $INSTALL = upgrade ]]; then
        txt_info "Also refer to the below for upgrade process ..."
        txt_url "${URLU}"
      fi
      txt_info "Or visit Netbox Community here ..."
      txt_url "${URLC}"
      GAME_OVER
    fi
    unset ATTEMPTS
  break
  fi
done
SL1

if ! [ -e $ROOT/v$NEWVER.tar.gz ]; then
  txt_err "File v$NEWVER.tar.gz still doesn't look to exist ..."
  txt_err "Manual intervention required ..."
  echo
  txt_info "Path here :"
  ls -lah $ROOT | egrep *.tar.gz
  echo
  GAME_OVER
else
  txt_ok "File v${NEWVER}.tar.gz is available in $(pwd)"
fi

printf '\n\n'
txt_header "+++ STAGE1 COMPLETE +++"
printf '\n\n'; SL2


#################################################################################################
txt_header "+++ STAGE2 : CHECK EXISTING NETBOX INSTALL +++"
printf '\n\n'; SL1

WILL_YOU_CONTINUE

SL1
echo
txt_warn "Script only supports symlink installs at this stage."
echo

txt_info "Checking directories..."

if ! [ -d $NBROOT ]; then
  txt_info "Netbox directory does not appear to exist ..."
  if [[ $INSTALL = new ]]; then
    SL1
    txt_ok "Missing directory expected of New install ..."
  elif [[ $INSTALL = upgrade ]]; then
    SL1
    txt_err "Unexpected outcome. Did you mean to select New install ..."
    GAME_OVER
  fi
elif [ -d $NBROOT ]; then
  if [ -e $NBROOT/.git ]; then
    ## PLACEHOLDER REMINDER
    # ADD GIT COMMANDS IN HERE
    txt_warn "Netbox directory exists but appears to be a Git install ..."
    txt_err "Git installs not yet supported. Script cannot continue ..."
    GAME_OVER
  elif [ -L $NBROOT ]; then
    txt_ok "Netbox directory is symbolically linked."
  else
    txt_err "Netbox directory exists but undetermined install type ..."
    txt_err "Script cannot continue ..."
    GAME_OVER
  fi
fi

SL2

# Will extract tar file as long as destination doesn't exist.
NBPATH=$NBROOT-$NEWVER

## PLACEHOLDER REMINDER
# Look to change this to a while loop

if [ -d $NBPATH ]; then
  txt_info "Path ${NBPATH} looks to exist already."
else
  txt_info "Extracting tar file to ${NBPATH} ..."
  tar -xzf v$NEWVER.tar.gz
  SL1
  txt_ok "... Extracted"
fi
SL1

echo
if ! [ -d $NBPATH ]; then
  txt_err "Path ${NBPATH} still doesn't look to exist ..."
  txt_err "Manual intervention required ..."
  txt_norm "Path here :"
  ls -lah $ROOT | grep netbox
  echo
  GAME_OVER
fi

printf '\n\n'
txt_header "+++ STAGE2 COMPLETE +++"
printf '\n\n'; SL2

#################################################################################################
txt_header "+++ BACKUP FILES AND DATABASE +++"

WILL_YOU_CONTINUE

TIME=$(date +%y-%m-%d_%H-%M)
BKPATH=$BKROOT/$TIME

if [[ $INSTALL = new ]]; then
  txt_norm "New install selected. Nothing to backup ..."
## PLACEHOLDER REMINDER : Revise code. Possibly redundant, at least at this stage.
elif [[ $INSTALL = git ]]; then
  txt_err "Git installs not yet supported. Script cannot continue ..."
  GAME_OVER
elif [[ $INSTALL = upgrade ]]; then
  mkdir -p $BKPATH  
  cp $NBROOT/{local_requirements.txt,gunicorn.py} $BKPATH/
  cp $NBROOT/netbox/netbox/{configuration.py,ldap_config.py} $BKPATH/
  txt_info "Backed up files here: "
  ls -lah $BKPATH/
  ## PLACEHOLDER REMINDER : COME BACK TO THIS
  txt_warn "TODO: DATABASE BACKUP STUFF HERE"
  txt_warn "TODO: TAR FILES HERE"
  txt_warn "TODO: DELETE SOURCE FILES ONCE TAR'd"
fi
SL1

unset TIME

printf '\n\n'
txt_header "+++ STAGE3 COMPLETE +++"
printf '\n\n'; SL2

#################################################################################################
txt_header "+++ STAGE4 : COPY FILES TO NEW NETBOX VERSION +++"

WILL_YOU_CONTINUE

if [[ $INSTALL = new ]]; then
  txt_info "New install selected. Nothing to copy ..."
elif [[ $INSTALL = git ]]; then
  ## PLACEHOLDER REMINDER : COME BACK TO THIS
  txt_err "Git installs not yet supported. Script cannot continue ..."
  GAME_OVER
elif [[ $INSTALL = upgrade ]]; then
  cp $NBROOT/{local_requirements.txt,gunicorn.py} $NBROOT-$NEWVER/
  cp $NBROOT/netbox/netbox/{configuration.py,ldap_config.py} $NBROOT-$NEWVER/netbox/netbox/
  # cp -pr $NBROOT-$OLDVER/netbox/media/ $NBROOT/netbox/
  # cp -r $NBROOT-$OLDVER/netbox/scripts $NBROOT/netbox/
  # cp -r $NBROOT-$OLDVER/netbox/reports $NBROOT/netbox/
elif [[ $INSTALL = git ]]; then
  txt_err "Git installs not yet supported. Script cannot continue ..."
  GAME_OVER
fi
SL1

printf '\n\n'
txt_header "+++ STAGE4 COMPLETE +++"
printf '\n\n'; SL2


#################################################################################################
txt_header "+++ STAGE5 - STOP NETBOX PROCESSES AND SYMLINK NEW +++"

txt_warn "Caution: This will make Netbox unavailable!"

WILL_YOU_CONTINUE

## PLACEHOLDER REMINDER
# look to change to a while loop
# look to optimise counter vars

if [[ $INSTALL = upgrade ]]; then
  OLDVER=$(ls -ld ${NBROOT} | awk -F"${NBROOT}-" '{print $2}' | cut -d / -f 1)
  if ! [[ $OLDVER =~ $REGEXVER ]]; then
    txt_warn "Discovered '${OLDVER}' doesn't look to be valid (eg 3.6.0) ..."
    SL1
    echo
    txt_info "Directory list here:"
    ls -ld $NBROOT | grep netbox
    while true; do
      read -p "Please manually enter existing Netbox release (eg 3.6.0) and press Enter: " OLDVER
      if ! [[ $OLDVER =~ $REGEXVER ]]; then
        if [[ $ATTEMPTS > 1 ]]; then
          txt_err "... Three incorrect attempts made.${CLR}"
          GAME_OVER
        fi
        txt_warn "Selection '${OLDVER}' format STILL not valid (eg 3.6.0). Try again ..."
        ATTEMPTS=$(( ATTEMPTS +1 ))
        SL1
        continue
      elif [[ $OLDVER =~ $REGEXVER ]]; then
        txt_ok "Selection '${OLDVER}' looks to be valid ..."
        break
      fi
      unset ATTEMPTS
    done
  fi
  SL1
  if [[ `echo "$OLDVER $NEWVER" | awk '{print ($1 > $2)}'` == 1 ]]; then
    txt_err "Current version (${OLDVER}) looks to be newer than the installing version (${NEWVER}) !"
    GAME_OVER
  fi
fi

if [[ $INSTALL = new ]]; then
  txt_warn "New install selected. No processes to stop ..."
elif [[ $INSTALL = git ]]; then
  txt_err "Git installs not yet supported. Script cannot continue ..."
  GAME_OVER
elif [[ $INSTALL = upgrade ]]; then
  systemctl stop netbox netbox-rq
  ## PLACEHOLDER REMINDER : validate they have actually stopped
  txt_ok "Processes netbox and netbox-rq stopped ..."
  SL1
  sudo ln -sfn $NBROOT-$NEWVER/ $NBROOT
  txt_info "Backed up files here: "
fi
SL1

txt_info "Running the Netbox upgrade script..."
bash $NBROOT/upgrade.sh | tee upgrade_(date +%y-%m-%d_%H-%M).log
txt_ok "Script has been run"

WILL_YOU_CONTINUE

txt_info "Restarting Netbox processes ..."
systemctl restart netbox netbox-rq
txt_ok "Processes restarted"


printf '\n\n'; SL2
txt_header "+++ STAGE5 COMPLETE +++"
printf '\n\n'; SL2


#################################################################################################

txt_err "Script stops here for now"
txt_err "Refinement ongoing"

# PLACEHOLDER REMINDER : TEMPORARY EXIT
GAME_OVER





#################################################################################################





apt update


#################################################################################################
txt_header "+++ STAGEa - SETUP POSTGRESQL +++"

WILL_YOU_CONTINUE

# https://docs.netbox.dev/en/stable/installation/1-postgresql/


$PKG_MGR $PKG_PSQL

set -e

txt_info "Setting up PostgreSQL"
echo
SL1

# These options are here, but highly recommended to stick with the static vars.
#read -p "Enter owner database name (suggested: 'netbox'): " DB_USER
#read -p "Enter database name (suggested: 'netbox'): " DB_NAME

DB_USER=netbox
DB_NAME=netbox
DB_PASS=$(openssl rand -base64 32)

printf '%b\n' "Displaying password ..."
SL1
echo
txt_warn "STORE PASSWORD SECURELY. DO NOT LOSE."
echo
echo "$DB_PASS" | tee -a .DB_PASS
echo
txt_warn "STORE PASSWORD SECURELY. DO NOT LOSE."
SL1

WILL_YOU_CONTINUE

su postgres <<EOF
psql -c "CREATE DATABASE $DB_NAME;"
psql -c "CREATE USER $DB_USER WITH PASSWORD '$DB_PASS';"
psql -c "ALTER DATABASE $DB_NAME OWNER TO $DB_USER;"
EOF

txt_ok "PostgreSQL database setup done."

# the next two commands are needed on PostgreSQL 15 and later
#su postgres <<EOF
#psql -c "\connect $DB_USER";
#psql -c "GRANT CREATE ON SCHEMA public TO $DB_USER";
#EOF

SL1

## TO VERIFY
   # $ psql --username netbox --password --host localhost netbox
   # Password for user netbox: 
   # psql (12.5 (Ubuntu 12.5-0ubuntu0.20.04.1))
   # SSL connection (protocol: TLSv1.3, cipher: TLS_AES_256_GCM_SHA384, bits: 256, compression: off)
   # Type "help" for help.
   # 
   # netbox=> \conninfo
   # You are connected to database "netbox" as user "netbox" on host "localhost" (address "127.0.0.1") at port "5432".
   # SSL connection (protocol: TLSv1.3, cipher: TLS_AES_256_GCM_SHA384, bits: 256, compression: off)
   # netbox=> \q


printf '\n\n'
txt_header "+++ STAGEa DONE +++"
printf '\n\n'; SL2


#################################################################################################
txt_header "+++ STAGEb - SETUP REDIS +++"

WILL_YOU_CONTINUE

txt_info "Installing packages for Redis"
$PKG_MGR $PKG_REDIS

redis-server -v
redis-cli ping

SL2

txt_header "+++ STAGEb DONE +++"
printf '\n\n'; SL2

#################################################################################################
txt_header "+++ STAGEc - SETUP NETBOX +++"

WILL_YOU_CONTINUE

nbv() {
  source $NBROOT/venv/bin/activate
}

nbs() {
  source $NBROOT/venv/bin/activate
  python3 $NBROOT/netbox/manage.py nbshell
}

$PKG_MGR $PKG_NETBOX

adduser --system --group netbox
chown --recursive netbox $NBMEDIA
chown --recursive netbox $NBREPORTS
chown --recursive netbox $NBSCRIPTS

cd $NBROOT/netbox/netbox/
cp configuration_example.py configuration.py

msg_info "Updating configuration.py ..."

txt_info "Before: ALLOWED_HOSTS"
printf '%b\n' "$(cat configuration.py | grep -F "ALLOWED_HOSTS = [" | grep -v Example)"
txt_info "Before: Netbox Database User"
printf '%b\n' "$(cat configuration.py | grep -F "'USER': '")"
txt_info "Before: Password for User"
printf '%b\n' "$(cat configuration.py | grep -F "'PASSWORD': '" | grep -F "PostgreSQL")"

sed -i "s|ALLOWED_HOSTS = \[\]|ALLOWED_HOSTS = \[*\]|g" configuration.py
sed -i "s|USER': '',|'USER': '$DB_USER',|g" configuration.py
sed -i "s|'PASSWORD': '',           # PostgreSQL password|'PASSWORD': '$DB_PASS',           # PostgreSQL password|g" configuration.py

SL2
txt_info "After: ALLOWED_HOSTS"
printf '%b\n' "$(cat configuration.py | grep -F "ALLOWED_HOSTS = [" | grep -v Example)"
txt_info "After: Netbox Database User"
printf '%b\n' "$(cat configuration.py | grep -F "'USER': '")"
txt_info "After: Password for User"
printf '%b\n' "$(cat configuration.py | grep -F "'PASSWORD': '" | grep -F "PostgreSQL")"

# Hint: Square brackets '[]' need escaping '\[\]'. Possibly others.
# sed -i "s|VARIABLE1|VARIABLE2|g" file.txt

## PLACEHOLDER REMINDER : Come back to this to possibly do conditionals/prompts

## OPTIONAL : This will change the media, reports and scripts paths. Here for reference. Might make it a choice later.

#printf '%b\n' "$(cat configuration.py | grep -F "MEDIA_ROOT")"
#sed -i "s|# MEDIA_ROOT = '/opt/netbox/netbox/media'|MEDIA_ROOT = '$NBMEDIA'|g" configuration.py
#printf '%b\n' "$(cat configuration.py | grep -F "MEDIA_ROOT")"
#
#printf '%b\n' "$(cat configuration.py | grep -F "REPORTS_ROOT")"
#sed -i "s|# REPORTS_ROOT = '/opt/netbox/netbox/reports'|REPORTS_ROOT = '$NBREPORTS'|g" configuration.py
#printf '%b\n' "$(cat configuration.py | grep -F "REPORTS_ROOT")"
#
#printf '%b\n' "$(cat configuration.py | grep -F "SCRIPTS_ROOT")"
#sed -i "s|# SCRIPTS_ROOT = '/opt/netbox/netbox/scripts'|SCRIPTS_ROOT = '$NBSCRIPTS'|g" configuration.py
#printf '%b\n' "$(cat configuration.py | grep -F "SCRIPTS_ROOT")"


txt_warn "Clearing DB_PASS variable. Temporarily stored as file .DB_PASS in $(pwd)"
unset DB_PASS


# ------------------------------------------------


txt_info "Generate a secret key"
python3 ../generate_secret_key.py

txt_info "Run Netbox upgrade script ..."
bash $NBROOT/upgrade.sh
echo -e "---------------------------------------------"
echo
SL2

txt_info "Create Superuser"
SL1

NB_VENV
python3 $NBROOT/netbox/manage.py createsuperuser

SL1
txt_info "Adding dulwich to local_requirements.txt for Git source capability"
echo 'dulwich' >> $NBROOT/local_requirements.txt

txt_info "Adding Housekeeping to cron tasks"
ln -s $NBROOT/contrib/netbox-housekeeping.sh /etc/cron.daily/netbox-housekeeping


txt_header "+++ STAGEc DONE +++"
printf '\n\n'; SL2

#################################################################################################
txt_header "+++ STAGEd - SETUP GUNICORN +++"

WILL_YOU_CONTINUE

$PKG_MGR $PKG_WWW


txt_header "+++ STAGEd DONE +++"
printf '\n\n'; SL2

#################################################################################################
txt_header "+++ STAGEe - SETUP NGINX +++"

WILL_YOU_CONTINUE

## PLACEHOLDER REMINDER : use certbot to properly do this

txt_info "Create certs..."

openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
-keyout /etc/ssl/private/netbox.key \
-out /etc/ssl/certs/netbox.crt

txt_ok "... done"

$PKG_MGR $PKG_WWW

cp $NBROOT/contrib/nginx.conf /etc/nginx/sites-available/netbox

NB_DNS=netbox.local
WWW=nginx

txt_info "Adjusting $WWW config server name"
printf '%b\n' "$(cat /etc/nginx/sites-available/netbox | grep -F "server_name"
sed -i "s|netbox.example.com|$NB_DNS|g" /etc/nginx/sites-available/netbox
SL1
printf '%b\n' "$(cat /etc/nginx/sites-available/netbox | grep -F "server_name"


rm /etc/nginx/sites-enabled/default
ln -s /etc/nginx/sites-available/netbox /etc/nginx/sites-enabled/netbox

systemctl restart nginx

txt_header "+++ STAGEe DONE +++"
printf '\n\n'; SL2

#################################################################################################
txt_header "+++ STAGEf - SETUP CERTIFICATES +++"





#################################################################################################
#################################################################################################
# Resources
#------------------------------------------------------------------------------------------------
# wget:
#   https://unix.stackexchange.com/questions/474805/verify-if-a-url-exists
# bash exit codes:
#   https://www.cyberciti.biz/faq/linux-bash-exit-status-set-exit-statusin-bash/
# Bash inputs:
#   https://ryanstutorials.net/bash-scripting-tutorial/bash-input.php
# bash colours:
# tput colours:
#   https://linuxcommand.org/lc3_adv_tput.php
#   https://unix.stackexchange.com/questions/269077/tput-setaf-color-table-how-to-determine-color-codes
#   https://stackoverflow.com/questions/54838578/color-codes-for-tput-setf
# interrupts:
#   https://www.putorius.net/using-trap-to-exit-bash-scripts-cleanly.html
# for loop count:
#   https://stackoverflow.com/questions/10515964/counter-increment-in-bash-loop-not-working
# check for files and symlinks etc
#   https://stackoverflow.com/questions/5767062/how-to-check-if-a-symlink-exists
#   https://devconnected.com/how-to-check-if-file-or-directory-exists-in-bash/
# check for sudo/root
#   https://electrictoolbox.com/check-user-root-sudo-before-running/
# break out of bash if condition (inconclusive)
#   https://stackoverflow.com/questions/21011010/how-to-break-out-of-an-if-loop-in-bash
# prompts
#   https://stackoverflow.com/questions/1885525/how-do-i-prompt-a-user-for-confirmation-in-bash-script
# awk decimal compare
#   https://stackoverflow.com/questions/11237794/how-to-compare-two-decimal-numbers-in-bash-awk
# awk filename sort
#   https://stackoverflow.com/questions/13078490/extracting-version-number-from-a-filename
# while loops
#   https://stackoverflow.com/questions/24896455/goto-beginning-of-if-statement
#   https://stackoverflow.com/questions/7955984/bash-if-return-code-1-re-run-script-start-at-the-beginning
# printf
#   https://stackoverflow.com/questions/27464569/bash-result-of-multiple-echo-commands-with-a-delay-on-one-line
# printf colours
#   https://stackoverflow.com/questions/5412761/using-colors-with-printf
# functions" eg FUNCTION() { stuff; some_more_stuff; }
#   https://phoenixnap.com/kb/bash-function
#   https://linuxize.com/post/bash-functions/
#   https://phoenixnap.com/kb/bash-function
#   https://www.baeldung.com/linux/bash-pass-function-arg
# alpha characters in conditionals
#   https://unix.stackexchange.com/questions/416108/how-to-check-if-string-contain-alphabetic-characters-or-alphabetic-characters-an
# regex:
#   https://stackoverflow.com/questions/18709962/regex-matching-in-a-bash-if-statement
#   https://www.baeldung.com/linux/regex-inside-if-clause
# unset var
#   https://www.cyberciti.biz/faq/linux-osx-bsd-unix-bash-undefine-environment-variable/
#
# postgres bash
#   https://stackfame.com/creating-user-database-and-adding-access-on-postgresql
#
#
# Python venv in Shell
#   https://stackoverflow.com/questions/13122137/how-to-source-virtualenv-activate-in-a-bash-script



#################################################################################################