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

# LET'S GO!
clear

# Checks you are root or sudo and pkg manager, quits if no sudo and/or no apt/yum.
ROOT_CHECK
PKG_MGR_CHECK



#################################################################################################

# Local path variables
     #=# PLACEHOLDER REMINDER : Change these to choices, with defaults.
ROOT=/opt
NBROOT=$ROOT/netbox
BKROOT=$ROOT/nb-backup

NBMEDIA=$NBROOT/netbox/media/
NBREPORTS=$NBROOT/netbox/reports/
NBSCRIPTS=$NBROOT/netbox/scripts/


# Local Netbox functions
nbv() { source $NBROOT/venv/bin/activate; }
nbmg() { nbv; python3 $NBROOT/netbox/manage.py $1; }
nbs() { nbv; python3 $NBROOT/netbox/manage.py nbshell; }


# Variables to validate Netbox release version inputs etc.
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


# Packages in various stages.
     #=# PLACEHOLDER REMINDER : Plan on making this interactive.
PKG_SCRIPT="wget tar nano openssl"
PKG_GIT="git"
PKG_PSQL="postgresql"
PKG_REDIS="redis-server"
PKG_NETBOX="python3 python3-pip python3-venv python3-dev build-essential libxml2-dev libxslt1-dev libffi-dev libpq-dev libssl-dev zlib1g-dev"
PKG_WWW="nginx"

CR2; SL1



#################################################################################################


# Check critical packages installed. Exit if not.
txt_info "Running a package update..."
$PMUPD
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
# Make deterministic choice of install type


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
      txt_err "Selection (${NEWVER}) at least 1 major release older than (${MAJOR1}) in Netbox project!"
      txt_err "Selection too old! Select again ..."
      continue
    elif [[ $(echo "$NEWVER $MINOR2" | awk '{print ($1 < $2)}') == 1 ]]; then
      txt_warn "Selection (${NEWVER}) at least 2 minor releases older than (${MINOR2}) in Netbox project!"
      txt_warn "Highly recommended to select a newer release!"
    elif [[ $(echo "$NEWVER $MINOR1" | awk '{print ($1 < $2)}') == 1 ]]; then
      txt_warn "Selected (${NEWVER}) at least 1 minor release older than (${MINOR1}) in Netbox project!"
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

     #=# PLACEHOLDER REMINDER
     # Bake in to while loop above. Inefficient code.

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
       #=# PLACEHOLDER REMINDER
       # File presence validations before copy eg ldap
  cp $NBROOT/local_requirements.txt "${BKPATH}/"
  cp $NBROOT/gunicorn.py "${BKPATH}/"
  cp $NBROOT/netbox/netbox/configuration.py "${BKPATH}/"
  cp $NBROOT/netbox/netbox/ldap_config.py "${BKPATH}/"
  txt_info "Backed up files here: "
  ls -lah "${BKPATH}"/
       #=# PLACEHOLDER REMINDER
       # Come back to this for database backup etc
  #txt_warn "TODO: DATABASE BACKUP STUFF HERE"
  #txt_warn "TODO: TAR FILES HERE"
  #txt_warn "TODO: DELETE SOURCE FILES ONCE TAR'd"
txt_header "+++ STAGE3 COMPLETE +++"
unset TIME
fi





#################################################################################################


if [[ $INSTALL = upgrade ]]; then
  txt_header "+++ UPGRADE COPY : FILES TO NEW NETBOX DIR +++"

  WILL_YOU_CONTINUE
  #
       #=# PLACEHOLDER REMINDER
       # Check files exist before copying
       # eg ldap and gunicorn might not
  cp $NBROOT/local_requirements.txt "${NBROOT}-${NEWVER}/"
  cp $NBROOT/gunicorn.py "${NBROOT}-${NEWVER}/"
  cp $NBROOT/netbox/netbox/configuration.py "${NBROOT}-${NEWVER}/netbox/netbox/"
  cp $NBROOT/netbox/netbox/ldap_config.py "${NBROOT}-${NEWVER}/netbox/netbox/"
       #=# PLACEHOLDER REMINDER
       # Add below in to presence validation and backup if so.
       # Consider adding filesize validation too.
  # cp -pr $NBROOT-$OLDVER/netbox/media/ $NBROOT/netbox/
  # cp -r $NBROOT-$OLDVER/netbox/scripts $NBROOT/netbox/
  # cp -r $NBROOT-$OLDVER/netbox/reports $NBROOT/netbox/

  txt_header "+++ UPGRADE COPY : COMPLETE +++"
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
       #=# PLACEHOLDER REMINDER : Figure out this syntax. Needs more observation.
  #https://stackoverflow.com/questions/8654051/how-can-i-compare-two-floating-point-numbers-in-bash
  #if awk "BEGIN {exit !($NEWVER >= $OLDVER)}"; then
  #if [[ awk "BEGIN {exit !($NEWVER >= $OLDVER)}" == 1 ]]; then
  if [[ $(echo "${NEWVER} ${OLDVER}" | awk '{print ($1 >= $2)}') == 0 ]]; then
    txt_err "Current version (${OLDVER}) same or newer than installing version (${NEWVER}) !"
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
       #=# PLACEHOLDER REMINDER
       # Validate processes have actually stopped
  txt_ok "Processes netbox and netbox-rq stopped ..."
  SL1
  ln -sfn "${NBROOT}-${NEWVER}"/ "${NBROOT}"
  txt_info "Backed up files here: "
       #=# PLACEHOLDER REMINDER
       # Finish this off
fi

if [[ $INSTALL = upgrade ]]; then
  txt_info "Symlinking New ${NEWVER} to ${NBROOT}"
  ln -sfn "${NBROOT}-${NEWVER}"/ "${NBROOT}"
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
  
       #=# PLACEHOLDER REMINDER
       # Wrap this up in a loop with user input for self-generation.
       # Will need to validate secret password since Netbox requires 50+ characters.             
  #DB_PASS=$(openssl rand -base64 51)
  DB_PASS=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 61 ; echo '')
  SC_PASS=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 61 ; echo '')
  
  
       #=# PLACEHOLDER REMINDER : Check for password file before regen."
  txt_info "Displaying password ..."
  CR1; SL1
  txt_warn "STORE PASSWORD SECURELY. DO NOT LOSE."
  CR1
  txt_info "Database Password"
  echo "$DB_PASS" | tee .DB_PASS
  CR1
  txt_info "Netbox Secret Password"
  echo "$SC_PASS" | tee .SC_PASS
  txt_warn "STORE PASSWORD SECURELY. DO NOT LOSE."
  txt_ok "Password files '.DB_PASS' and '.SC_PASS' in (${pwd}) :"
  txt_nindent "$(pwd)"
  CR2; SL2
  
       #=# PLACEHOLDER REMINDER
       # Validate database creation before trying again.
       
  txt_info "Modifying database."
  su postgres <<EOF
psql -c "CREATE DATABASE $DB_NAME;"
psql -c "CREATE USER $DB_USER WITH PASSWORD '$DB_PASS';"
psql -c "ALTER DATABASE $DB_NAME OWNER TO $DB_USER;"
EOF
  
       #=# PLACEHOLDER REMINDER
       # Integrate these in to conditionals.  

  ##The next two commands are needed on PostgreSQL 15 and later
  #su postgres <<EOF
#psql -c "\connect $DB_USER";
#psql -c "GRANT CREATE ON SCHEMA public TO $DB_USER";
#EOF

  txt_ok "PostgreSQL database setup done."
  SL1
 txt_header "+++ STAGEa DONE +++"
 SL2
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
  
       #=# PLACEHOLDER REMINDER
       # Add auto-validation to capture the PONG to the ping. Consider intervention if not.
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
  
  ln -sfn "${NBROOT}-${NEWVER}"/ "${NBROOT}"

       #=# PLACEHOLDER REMINDER
       # Refactor this to align with operating system commands.
       # Below is Debian-based distros
  adduser --system --group netbox
  chown --recursive netbox $NBMEDIA
  chown --recursive netbox $NBREPORTS
  chown --recursive netbox $NBSCRIPTS
  
  cd "${NBROOT}/netbox/netbox/"
  cp configuration_example.py configuration.py
  
       #=# PLACEHOLDER REMINDER :
       # Validate files before editing (for concurrent runs).
       #
       # Also evaluate making this user input choice using the likes of nano.
       
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
  
       #=# PLACEHOLDER REMINDER
       # Come back to this to possibly do conditionals/prompts
  
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

  # Redundant since we do our own
  # txt_info "Generate a secret key"
  # python3 ../generate_secret_key.py | tee .NB_PASS
  # CR2; SL1
  
       #=# PLACEHOLDER REMINDER : Code duplicity with upgrade section above. Consolidate...
  txt_info "Run Netbox upgrade script ..."
  bash "${NBROOT}/upgrade.sh"
  CR2; SL2
  
  txt_info "Create Superuser"
  nbmg createsuperuser

  SL1
  txt_info "Adding dulwich to local_requirements.txt for Git source capability"
       #=# PLACEHOLDER REMINDER
       # Change this to version conditional - only needed for git on v3.6.0+
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
  cp -v "${NBROOT}/contrib/"*".service" "/etc/systemd/system/"

  txt_info "Starting Netbox processes..."
  systemctl daemon-reload
  systemctl start netbox netbox-rq
  systemctl enable netbox netbox-rq
  SL2
       #=# PLACEHOLDER REMINDER
       # Add service start validation. Perhaps make a counter loop.
  # systemctl status netbox.service

  txt_header "+++ STAGEd DONE +++"
  SL2
fi


#################################################################################################

     #=# PLACEHOLDER REMINDER
     # Make this a choice between Nginx and Apache
     # https://docs.netbox.dev/en/stable/installation/5-http-server/

if [[ $INSTALL = new ]]; then
  NB_DNS=netbox.local
  WWW=nginx

  $PMGET $PKG_WWW

  if [[ "${WWW}" = nginx ]]; then
    txt_header "+++ STAGEe - SETUP NGINX +++"
    SL0

    WILL_YOU_CONTINUE
  
       #=# PLACEHOLDER REMINDER
       # Place options, including use certbot to properly do this
    txt_info "Create certs..."; CR1; SL2
    openssl req -new -newkey rsa:4096 -days 365 -nodes -x509 \
    -subj "/C=NZ/ST=Denial/L=RiverIn/O=Ejypt/CN=${NB_DNS}" \
    -keyout /etc/ssl/private/netbox.key \
    -out /etc/ssl/certs/netbox.crt
    txt_ok "... done"; CR1
  
    cp $NBROOT/contrib/nginx.conf /etc/nginx/sites-available/netbox
       #=# PLACEHOLDER REMINDER
       # Make this interactive

    txt_info "Adjusting ${WWW} config server name"
    printf '%b\n' "$(cat /etc/nginx/sites-available/netbox) | $(grep -F 'server_name')"
      sed -i "s|netbox.example.com|$NB_DNS|g" /etc/nginx/sites-available/netbox
    SL1
    printf '%b\n' "$(cat /etc/nginx/sites-available/netbox) | $(grep -F 'server_name')"
  
    rm /etc/nginx/sites-enabled/default
    ln -s /etc/nginx/sites-available/netbox /etc/nginx/sites-enabled/netbox

    #=# PLACEHOLDER REMINDER
    # Add start validation
    systemctl restart nginx
  
  fi
  txt_header "+++ STAGEe DONE +++"
  SL2
fi

#################################################################################################

     ## PLACEHOLDER REMINDER : Perform this process.
# txt_header "+++ STAGEf - SETUP CERTIFICATES +++"


#################################################################################################

txt_header "+++ RUN INSTALL SCRIPT AND STARTING NETBOX +++"
     #=# PLACEHOLDER REMINDER
     # This applies to new/git installs also. Consider conolidating code.
txt_info "Running the Netbox upgrade script..."

     #=# PLACEHOLDER REMINDER
     # Adjust git for git-upgrade vs git-new install
if [[ $INSTALL = upgrade ]] || [[ $INSTALL = git ]]; then
  txt_warn "Likely no going back after this !"
  WILL_YOU_CONTINUE
fi

bash "${NBROOT}/upgrade.sh" | tee "upgrade_$(date +%y-%m-%d_%H-%M).log"
txt_ok "Netbox upgrade.sh has been run"

txt_info "Starting Netbox processes ..."
     #=# PLACEHOLDER REMINDER
     # Make this a better choice.
WILL_YOU_CONTINUE

     #=# PLACEHOLDER REMINDER
     # Add process start validation.
systemctl start netbox netbox-rq
txt_ok "Processes started"
SL2
systemctl status netbox netbox-rq

txt_header "+++ STAGEx COMPLETE +++"
SL2

# FINISHED !!
