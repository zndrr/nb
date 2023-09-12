#!/bin/bash

# Source definitions
if ! [ -e "global_vars.sh" ]; then echo ".sh Dependency missing! Exiting..." sleep 2; exit; fi
source global_vars.sh


GREETINGS_TRAVELLER() {
  cat <<"EOF"
# # # # # # # # # # # # # # # # # # # # # # # # # #
#
# Author
#  GitHub User : https://github.com/zndrr
#  Repo : https://github.com/zndrr/nb
#  License : MIT
#
#  Created: 2023-07-09
#  Updated: 2023-07-12
#
#   Script created in Bash 5.1.16(1) on Ubuntu.
#   Tested against Netbox v3.5.9 and v3.6.2
#
# # # # # # # # # # # # # # # # # # # # # # # # # #
EOF
}

SPEW_INTRO() {
  cat <<"EOF"
# # # # # # # # # # # # # # # # # # # # # # # # # #
#
# This aims to install or upgrade Netbox instance.
#
# Git install not supported at this stage.
# For Git install, please follow guidance.
#
# https://github.com/netbox-community/
# https://docs.netbox.dev/en/stable/installation/
#
# # # # # # # # # # # # # # # # # # # # # # # # # #
EOF
}


#################################################################################################

# Local path variables
     #=# PLACEHOLDER REMINDER : Change these to choices, with defaults.
ROOT=/opt
NBROOT=$ROOT/netbox
BKROOT=$ROOT/nb-backup

NBMEDIA=$NBROOT/netbox/media/
NBREPORTS=$NBROOT/netbox/reports/
NBSCRIPTS=$NBROOT/netbox/scripts/

# Local functions
nbv() { source $NBROOT/venv/bin/activate; }
nbmg() { nbv; python3 $NBROOT/netbox/manage.py $1; }
nbs() { nbv; python3 $NBROOT/netbox/manage.py nbshell; }

# Variables to validate release version inputs etc.
# Check and update periodically as newer releases roll around.
REGEXVER="^[0-9].[0-9].[0-9]{1,2}$"
MINOR1=3.6.0
MINOR2=3.5.0
MAJOR1=3.0.0

# URL variables for text output. Update if they change.
URLU="https://docs.netbox.dev/en/stable/installation/upgrading/"
URLN="https://docs.netbox.dev/en/stable/installation/"
URLR="https://github.com/netbox-community/netbox/releases/"
URLC="https://github.com/netbox-community/"


# Packages managers. Tentatively covers apt (Debian) or CentOS (yum) only.
     #=# PLACEHOLDER REMINDER : To work on autodiscover and/or user input.
PM=apt
#PM=yum
PMU="${PM} update"
PMGET="${PM} install -y"

# Packages in various stages.
     #=# PLACEHOLDER REMINDER : Plan on making this interactive.
PKG_SCRIPT="wget tar nano openssl"
PKG_GIT="git"
PKG_PSQL="postgresql"
PKG_REDIS="redis-server"
PKG_NETBOX="python3 python3-pip python3-venv python3-dev build-essential libxml2-dev libxslt1-dev libffi-dev libpq-dev libssl-dev zlib1g-dev"
PKG_WWW="nginx"

#################################################################################################
# Sanity checks for successful script execution

clear

# Checks you are root or sudo
ROOT_CHECK

CR2; SL1


# Check critical packages installed. Exit if not.
txt_info "Running a package update..."
$PMU
CR2; SL1

txt_info "Checking packages required for script ..."

for pkg in $PKG_SCRIPT; do
  command -v "${pkg}" &>/dev/null
  if [[ $pkg = 0 ]]; then
    txt_warn "Package '${pkg}' is not installed!"
    PKGMISSING=$(( PKGMISSING + 1 ))
    SL0
  fi
done

if [[ $PKGMISSING -gt 0 ]]; then
  txt_err "... Script cannot run without these packages."
  GAME_OVER
fi

txt_ok "Packages okay. Continuing ..."
CR2; SL1

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
            CR2
            SL1
            ;;
        Quit)
            GAME_OVER;;
        *)
            txt_warn "Invalid option '${REPLY}'. Try again..."
            CR2
            SL1
            ;;
     esac
done
CR1; SL1

txt_info "Will proceed with ${INSTALL} install ..."

SL1

#################################################################################################
# Start script here

txt_header "+++ STAGE1 : DOWNLOADING NETBOX ARCHIVE FILE +++"

txt_info "Moving in to ${ROOT} directory ..."
mkdir -p "${ROOT}"
cd "${ROOT}"

SL2


while true; do
  COUNT=0
  CR1
  read -p "Please enter desired Netbox release (eg 3.6.0) and press Enter: " NEWVER
  URLD="https://github.com/netbox-community/netbox/archive/v${NEWVER}.tar.gz"
  if ! [[ $NEWVER =~ $REGEXVER ]]; then
    if [[ "${COUNT}" -gt 2 ]]; then
      txt_err "... Too many incorrect attempts made."
      GAME_OVER
    fi
    txt_warn "Selection '${NEWVER}' not valid (eg 3.6.0). Try again ..."
    ((COUNT++))
    SL1
    continue
  elif [ -e "${ROOT}/v${NEWVER}.tar.gz" ]; then
    txt_ok "File looks to exist already. Download not required ..."
    break
  elif ! [ -e "${ROOT}/v${NEWVER}.tar.gz" ]; then
    if [[ $(echo "$NEWVER $MAJOR1" | awk '{print ($1 < $2)}') == 1 ]]; then
      txt_err "Current selection (${NEWVER}) looks to be at least 1 major release older than (${MAJOR1}) !"
      txt_err "Selection too old! Select again ..."
      continue
    elif [[ $(echo "$NEWVER $MINOR2" | awk '{print ($1 < $2)}') == 1 ]]; then
      txt_warn "Current selection (${NEWVER}) looks to be at least 2 minor releases older than (${MINOR2}) !"
      txt_warn "Highly recommended to seek a newer release !"
    elif [[ $(echo "$NEWVER $MINOR1" | awk '{print ($1 < $2)}') == 1 ]]; then
      txt_warn "Current selection (${NEWVER}) looks to be at least 1 minor release older than (${MINOR1}) !"
    SL1
    fi
    txt_info "Checking availability ..."
    if wget --spider "${URLD}" 2>/dev/null; then
      txt_ok "Release v${NEWVER} found. Downloading ..."
      SL1
      wget -q --show-progress "${URLD}" -P "${ROOT}/" --no-check-certificate
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

     #=# PLACEHOLDER REMINDER : Bake in to while loop above

# Double-checking tarball exists
if ! [ -e "${ROOT}/v${NEWVER}.tar.gz" ]; then
  txt_err "File v${NEWVER}.tar.gz still doesn't look to exist ..."
  txt_err "Manual intervention required ..."
  echo
  txt_info "Path here :"
  ls -lah "${ROOT}" | egrep *.tar.gz
  echo
  GAME_OVER
else
  txt_ok "File v${NEWVER}.tar.gz is available in $(pwd)"
fi

CR2
txt_header "+++ STAGE1 COMPLETE +++"
CR2; SL2


#################################################################################################
txt_header "+++ STAGE2 : CHECK EXISTING NETBOX INSTALL +++"
CR2; SL1

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
    txt_ok "Missing directory expected of New install"
  elif [[ $INSTALL = upgrade ]]; then
    SL1
    txt_err "Unexpected outcome. Did you mean to select New install ..."
    GAME_OVER
  fi
elif [ -d $NBROOT ]; then
  if [ -e $NBROOT/.git ]; then
         #=# PLACEHOLDER REMINDER
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

     #=# PLACEHOLDER REMINDER
# Look to change this to a while loop

if [ -d "${NBPATH}" ]; then
  txt_info "Path ${NBPATH} looks to exist already."
else
  txt_info "Extracting tar file to ${NBPATH} ..."
  tar -xzf "v${NEWVER}.tar.gz"
  SL1
  txt_ok "... Extracted"
fi
SL1

echo
if ! [ -d "${NBPATH}" ]; then
  txt_err "Path ${NBPATH} still doesn't look to exist ..."
  txt_err "Manual intervention required ..."
  txt_norm "Path here :"
  ls -lah "${ROOT}" | grep netbox
  echo
  GAME_OVER
fi

CR2
txt_header "+++ STAGE2 COMPLETE +++"
CR2; SL2

#################################################################################################


     #=# PLACEHOLDER REMINDER : Revise code. Some redundant, at least at this stage.
#elif [[ $INSTALL = git ]]; then
#  txt_err "Git installs not yet supported. Script cannot continue ..."
#  GAME_OVER
#if [[ $INSTALL = upgrade ]] || [[ $INSTALL = git ]]; then
if [[ $INSTALL = upgrade ]]; then
  txt_header "+++ STAGE3 : BACKUP FILES AND DATABASE +++"

  WILL_YOU_CONTINUE

  TIME=$(date +%y-%m-%d_%H-%M)
  BKPATH="${BKROOT}/${TIME}"

  mkdir -p "${BKPATH}"  
  cp $NBROOT/{local_requirements.txt,gunicorn.py} "${BKPATH}/"
  cp $NBROOT/netbox/netbox/{configuration.py,ldap_config.py} "${BKPATH}/"
  txt_info "Backed up files here: "
  ls -lah "${BKPATH}"/
       #=# PLACEHOLDER REMINDER : COME BACK TO THIS FOR DB BACKUP ETC
  txt_warn "TODO: DATABASE BACKUP STUFF HERE"
  txt_warn "TODO: TAR FILES HERE"
  txt_warn "TODO: DELETE SOURCE FILES ONCE TAR'd"
txt_header "+++ STAGE3 COMPLETE +++"
unset TIME
fi





#################################################################################################





if [[ $INSTALL = upgrade ]]; then
  txt_header "+++ STAGE4 : COPY FILES TO NEW NETBOX VERSION +++"

  WILL_YOU_CONTINUE

  cp $NBROOT/{local_requirements.txt,gunicorn.py} "${NBROOT}-${NEWVER}/"
  cp $NBROOT/netbox/netbox/{configuration.py,ldap_config.py} "${NBROOT}-${NEWVER}/netbox/netbox/"
  # cp -pr $NBROOT-$OLDVER/netbox/media/ $NBROOT/netbox/
  # cp -r $NBROOT-$OLDVER/netbox/scripts $NBROOT/netbox/
  # cp -r $NBROOT-$OLDVER/netbox/reports $NBROOT/netbox/

  txt_header "+++ STAGE4 COMPLETE +++"
elif [[ $INSTALL = git ]]; then
       #=# PLACEHOLDER REMINDER : COME BACK TO THIS
  txt_err "Git installs not yet supported. Script cannot continue ..."
  GAME_OVER
fi

SL2





#################################################################################################
txt_header "+++ STAGE5 - STOP NETBOX PROCESSES AND SYMLINK NEW +++"

txt_warn "Caution: This will make Netbox unavailable!"

WILL_YOU_CONTINUE

     #=# PLACEHOLDER REMINDER
# look to change to a while loop
# look to optimise counter vars


if [[ $INSTALL = upgrade ]]; then


  OLDVER=$(ls -ld ${NBROOT} | awk -F"${NBROOT}-" '{print $2}' | cut -d / -f 1)
  if ! [[ $OLDVER =~ $REGEXVER ]]; then
    txt_warn "Discovered '${OLDVER}' doesn't look to be valid (eg 3.6.0) ..."
    SL1
    echo
    txt_info "Directory list here:"
    ls -ld "${NBROOT}" | grep netbox
    while true; do
      COUNT=0
      read -p "Please manually enter existing Netbox release (eg 3.6.0) and press Enter: " OLDVER
      if ! [[ $OLDVER =~ $REGEXVER ]]; then
        if [[ "${COUNT}" -gt 2 ]]; then
          txt_err "... Three incorrect attempts made.${CLR}"
          GAME_OVER
        fi
        txt_warn "Selection '${OLDVER}' format STILL not valid (eg 3.6.0). Try again ..."
        ((COUNT++))
        SL1
        continue
      elif [[ $OLDVER =~ $REGEXVER ]]; then
        txt_ok "Selection '${OLDVER}' looks to be valid ..."
        break
      fi
    done
  fi
  CR1; SL1
  txt_info "Comparing current (${OLDVER}) to installing (${NEWVER})"
       #=# PLACEHOLDER REMINDER : Figure out this syntax.
  #https://stackoverflow.com/questions/8654051/how-can-i-compare-two-floating-point-numbers-in-bash
  #if awk "BEGIN {exit !($NEWVER >= $OLDVER)}"; then
  #if [[ awk "BEGIN {exit !($NEWVER >= $OLDVER)}" == 1 ]]; then
  if [[ $(echo "${NEWVER} ${OLDVER}" | awk '{print ($1 >= $2)}') == 0 ]]; then
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
       #=# PLACEHOLDER REMINDER : validate they have actually stopped
  txt_ok "Processes netbox and netbox-rq stopped ..."
  SL1
  sudo ln -sfn "${NBROOT}-${NEWVER}"/ "${NBROOT}"
  txt_info "Backed up files here: "
fi

if [[ $INSTALL = git ]] || [[ $INSTALL = upgrade ]]; then
  txt_info "Symlinking New ${NEWVER} to ${NBROOT}"
  sudo ln -sfn "${NBROOT}-${NEWVER}"/ "${NBROOT}"
fi


SL2
txt_header "+++ STAGEx COMPLETE +++"
SL2

#################################################################################################

#################################################################################################
# https://docs.netbox.dev/en/stable/installation/1-postgresql/

if [[ $INSTALL = new ]]; then
  txt_header "+++ STAGEa - SETUP POSTGRESQL +++"
  txt_info "Setting up PostgreSQL"

  SL0
  WILL_YOU_CONTINUE

  txt_info "Installing packages '${PKG_PSQL}'"
  $PMGET $PKG_PSQL
  set -e
  echo
  SL1
  # These options are here, but highly recommended to stick with the static vars.
  #read -p "Enter owner database name (suggested: 'netbox'): " DB_USER
  #read -p "Enter database name (suggested: 'netbox'): " DB_NAME
       #=# PLACEHOLDER REMINDER : Will make this a choice later.
  DB_USER=netbox
  DB_NAME=netbox
  #DB_PASS=$(openssl rand -base64 51)
  DB_PASS=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 61 ; echo '')
  SC_PASS=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 61 ; echo '')
  
  
       #=# PLACEHOLDER REMINDER : Check for password file before regen."
  txt_info "Displaying password ..."
  SL1
  CR1
  txt_warn "STORE PASSWORD SECURELY. DO NOT LOSE."
  CR1
  txt_info "Database Password"
  echo "$DB_PASS" | tee .DB_PASS
  CR1
  txt_info "Netbox Secret Password"
  echo "$SC_PASS" | tee .SC_PASS
  txt_warn "STORE PASSWORD SECURELY. DO NOT LOSE."
  CR2; SL2
  
       #=# PLACEHOLDER REMINDER : Validate database creation before trying again.
       
  txt_info "Modifying database."
  su postgres <<EOF
psql -c "CREATE DATABASE $DB_NAME;"
psql -c "CREATE USER $DB_USER WITH PASSWORD '$DB_PASS';"
psql -c "ALTER DATABASE $DB_NAME OWNER TO $DB_USER;"
EOF
  
       #=# PLACEHOLDER REMINDER : Integrate these in to conditionals.  
  # the next two commands are needed on PostgreSQL 15 and later
  #su postgres <<EOF
  #psql -c "\connect $DB_USER";
  #psql -c "GRANT CREATE ON SCHEMA public TO $DB_USER";
  #EOF

  txt_ok "PostgreSQL database setup done."
  SL1
 txt_header "+++ STAGEa DONE +++"
 SL2
else
  txt_warn "New installs only. Skipping..."
fi

     #=# PLACEHOLDER REMINDER : Perhaps integrate this in to script.
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



#################################################################################################


if [[ $INSTALL = new ]]; then
  txt_header "+++ STAGEb - SETUP REDIS +++"
  WILL_YOU_CONTINUE
  
  txt_info "Installing packages for Redis"
  $PMGET $PKG_REDIS
  
  CR1
  txt_info "Redis checks..."
  SL1
  
  redis-server -v
  redis-cli ping
  
  SL2
  
  txt_header "+++ STAGEb DONE +++"
  SL2
fi


#################################################################################################


if [[ $INSTALL = new ]]; then
  txt_header "+++ STAGEc - SETUP NETBOX +++"
  
  SL0
  WILL_YOU_CONTINUE
  
  $PMGET $PKG_NETBOX
  
  sudo ln -sfn "${NBROOT}-${NEWVER}"/ "${NBROOT}"
  
  adduser --system --group netbox
  chown --recursive netbox $NBMEDIA
  chown --recursive netbox $NBREPORTS
  chown --recursive netbox $NBSCRIPTS
  
  cd "${NBROOT}/netbox/netbox/"
  cp configuration_example.py configuration.py
  
       #=# PLACEHOLDER REMINDER : Validate files before editing (for concurrent runs).
  txt_info "Updating configuration.py ..."
  CR1; SL1
  
  txt_info "Before: ALLOWED_HOSTS"
  printf '%b\n' "$(cat configuration.py | grep -F "ALLOWED_HOSTS = [" | grep -v Example)"
    sed -i "s|ALLOWED_HOSTS = \[\]|ALLOWED_HOSTS = \['*'\]|g" configuration.py
  txt_info "After: ALLOWED_HOSTS"
  printf '%b\n' "$(cat configuration.py | grep -F "ALLOWED_HOSTS = [" | grep -v Example)"
  CR2; SL1

  txt_info "Before: Netbox Database User"
  printf '%b\n' "$(cat configuration.py | grep -F "'USER': '")"
    sed -i "s|'USER': '',|'USER': '$DB_USER',|g" configuration.py
  txt_info "After: Netbox Database User"
  printf '%b\n' "$(cat configuration.py | grep -F "'USER': '")"
  CR2; SL1

  txt_info "Before: Password for User"
  printf '%b\n' "$(cat configuration.py | grep -F "'PASSWORD': '" | grep -F "PostgreSQL")"
    sed -i "s|'PASSWORD': '',           # PostgreSQL password|'PASSWORD': '$DB_PASS',           # PostgreSQL password|g" configuration.py
  txt_info "After: Password for User"
  printf '%b\n' "$(cat configuration.py | grep -F "'PASSWORD': '" | grep -F "PostgreSQL")"
  CR2; SL1

  txt_info "Before: Secret Pass for Netbox"
  printf '%b\n' "$(cat configuration.py | grep -F "SECRET_KEY = '")"
    sed -i "s|SECRET_KEY = ''|SECRET_KEY = '$SC_PASS'|g" configuration.py
  txt_info "After: Secret Pass for Netbox"
  printf '%b\n' "$(cat configuration.py | grep -F "SECRET_KEY = '")"
  CR2; SL1
  
  
  # Hint: Square brackets '[]' need escaping '\[\]'. Possibly others.
  # sed -i "s|VARIABLE1|VARIABLE2|g" file.txt
  
       #=# PLACEHOLDER REMINDER : Come back to this to possibly do conditionals/prompts
  
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
  
  
  #txt_warn "Clearing DB_PASS variable. Temporarily stored as file .DB_PASS in $(pwd)"
  #unset DB_PASS
  
  txt_info "Generate a secret key"
  python3 ../generate_secret_key.py | tee .NB_PASS
  CR2; SL1
  
       #=# PLACEHOLDER REMINDER : Code duplicity with upgrade section above. Consolidate...
  txt_info "Run Netbox upgrade script ..."
  bash "${NBROOT}/upgrade.sh"
  CR2; SL2
  
  txt_info "Create Superuser"
  nbmg createsuperuser

  SL1
  txt_info "Adding dulwich to local_requirements.txt for Git source capability"
       #=# PLACEHOLDER REMINDER : Change this to version conditional just in case v3.5.x
  echo 'dulwich' >> "${NBROOT}/local_requirements.txt"
  
  txt_info "Adding Housekeeping to cron tasks"
  ln -s "${NBROOT}/contrib/netbox-housekeeping.sh" /etc/cron.daily/netbox-housekeeping
  
  txt_header "+++ STAGEc DONE +++"
  SL2
fi


#################################################################################################

if [[ $INSTALL = new ]]; then
  txt_header "+++ STAGEd - SETUP GUNICORN +++"
  
  SL0
  WILL_YOU_CONTINUE
  
  cp "${NBROOT}/contrib/gunicorn.py" "${NBROOT}/gunicorn.py"
  cp -v "${NBROOT}/contrib/*.service" "/etc/systemd/system/"
  systemctl daemon-reload
  systemctl start netbox netbox-rq
  systemctl enable netbox netbox-rq
  systemctl status netbox.service

  txt_header "+++ STAGEd DONE +++"
  SL2
fi


#################################################################################################

     #=# PLACEHOLDER REMINDER : Make this a choice between Nginx and Apache
# https://docs.netbox.dev/en/stable/installation/5-http-server/

if [[ $INSTALL = new ]]; then
  txt_header "+++ STAGEe - SETUP NGINX +++"
  
  SL0
  WILL_YOU_CONTINUE
  
       #=# PLACEHOLDER REMINDER : Place options, including use certbot to properly do this
  
  txt_info "Create certs..."
  
  openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /etc/ssl/private/netbox.key \
  -out /etc/ssl/certs/netbox.crt
  
  txt_ok "... done"
  $PMGET $PKG_WWW
  
  cp $NBROOT/contrib/nginx.conf /etc/nginx/sites-available/netbox
  
  NB_DNS=netbox.local
  WWW=nginx
  
  txt_info "Adjusting ${WWW} config server name"
  printf '%b\n' "$(cat /etc/nginx/sites-available/netbox) | $(grep -F "server_name")"
  sed -i "s|netbox.example.com|$NB_DNS|g" /etc/nginx/sites-available/netbox
  SL1
  printf '%b\n' "$(cat /etc/nginx/sites-available/netbox) | $(grep -F "server_name")"
  
  rm /etc/nginx/sites-enabled/default
  ln -s /etc/nginx/sites-available/netbox /etc/nginx/sites-enabled/netbox
  
  systemctl restart nginx
  
  txt_header "+++ STAGEe DONE +++"
  SL2
fi

#################################################################################################

     ## PLACEHOLDER REMINDER : Perform this process.
# txt_header "+++ STAGEf - SETUP CERTIFICATES +++"


#################################################################################################
txt_header "+++ STAGEx - RUN INSTALL SCRIPT AND/OR STARTING NETBOX +++"


if [[ $INSTALL = upgrade ]]; then
  txt_info "Running the Netbox upgrade script..."
  txt_warn "Likely no going back after this !"
  
  WILL_YOU_CONTINUE
  
  bash "${NBROOT}/upgrade.sh" | tee "upgrade_$(date +%y-%m-%d_%H-%M).log"
  txt_ok "Script has been run"
fi

txt_info "Starting Netbox processes ..."

WILL_YOU_CONTINUE

systemctl start netbox netbox-rq
txt_ok "Processes restarted"

SL2
txt_header "+++ STAGEx COMPLETE +++"
SL2

#################################################################################################


#################################################################################################
#################################################################################################
# Resources
#------------------------------------------------------------------------------------------------
#
# sh checker -- thanks to colleague Blair for showing this
#   https://www.shellcheck.net/
#
# banner gen:
#   https://manytools.org/hacker-tools/ascii-banner/
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
