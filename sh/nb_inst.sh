#!/bin/bash

# Source definitions
if ! [ -e "env_global.sh" ]; then printf '%b\n' "env .sh Dependency missing! Exiting..." sleep 2; exit; fi
source env_global.sh

# Setting a script timer.
startTime=$(date +%s)

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
#  Updated: 2023-07-14
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

# LET'S GO! PS. printf rules, echo can suck it
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

      #=# PLACEHOLDER REMINDER : Revisit
      # These I want to suggest. Backups and external files would be best living outside Netbox path.
#NBMEDIA=$ROOT/nb/media/
#NBREPORTS=$ROOT/nb/reports/
#NBSCRIPTS=$ROOT/nb/scripts/

NBMEDIA=$NBROOT/netbox/media/
NBREPORTS=$NBROOT/netbox/reports/
NBSCRIPTS=$NBROOT/netbox/scripts/

# Local Netbox functions
nbv() { source $NBROOT/venv/bin/activate; }
nbmg() { nbv; python3 $NBROOT/netbox/manage.py "$1"; }
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

if [[ $PMGR = apt ]] || [[ $PMGR = yum]]; then
  PKG_GIT="git"
  PKG_WWW="nginx"
  if [[ $PMGR = apt ]]; then
    PKG_PSQL="postgresql"
    PKG_REDIS="redis-server"
    PKG_NETBOX="python3 python3-pip python3-venv python3-dev build-essential libxml2-dev libxslt1-dev libffi-dev libpq-dev libssl-dev zlib1g-dev"
    PKG_LDAP="libldap2-dev libsasl2-dev libssl-dev"
  elif [[ $PMGR = yum ]]; then
    PKG_PSQL="postgresql-server"
    PKG_REDIS="redis"
    PKG_NETBOX="gcc libxml2-devel libxslt-devel libffi-devel libpq-devel openssl-devel redhat-rpm-config"
    PKG_LDAP="openldap-devel python3-devel"
  fi
else
  txt_err "Exception. Distro not determined !"
  GAME_OVER
fi

SL1; CR2



#################################################################################################


# Check critical packages installed. Exit if not.
txt_info "Running a package update..."
$PMUPD
SL1; CR2

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
SL1; CR2



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

txt_header "----- DOWNLOADING NETBOX RELEASE -----"

txt_info "Moving in to ${ROOT} directory ..."
mkdir -p "${ROOT}"
cd "${ROOT}"

SL2

      #=# PLACEHOLDER REMINDER
      # Optimise this loop. Bit of redundancy in checks.

COUNT=0
while true; do
  CR1
  read -p "Please enter desired Netbox release (eg 3.6.0) and press Enter: " -r NEWVER
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
      txt_err "Selection (${NEWVER}) at least 1 MAJOR release behind project (${MAJOR1}) !"
      txt_err "Selection too old! Select again ..."
      continue
    elif [[ $(echo "$NEWVER $MINOR2" | awk '{print ($1 < $2)}') == 1 ]]; then
      txt_warn "Selection (${NEWVER}) at least 2 minor releases behind project (${MINOR1}) !"
      txt_warn "Highly recommended to select a newer release!"
    elif [[ $(echo "$NEWVER $MINOR1" | awk '{print ($1 < $2)}') == 1 ]]; then
      txt_warn "Selection '${NEWVER}' at least 1 minor release behind project '${MINOR1}' !"
    SL1
    fi
    txt_info "Checking availability ..."
    if wget --spider "${URLD}" 2>/dev/null; then
      txt_ok "Release v${NEWVER} found."
      SL1; CR1
      txt_info "Downloading ..."
      SL1
      wget -q --show-progress "${URLD}" -P "${ROOT}/" --no-check-certificate
      SL1
      txt_ok "... Download complete!"
      # Double-checking tarball exists
      txt_info "Confirming file present after download ..."
      SL0; CR1
      if ! [ -e "${ROOT}/v${NEWVER}.tar.gz" ]; then
        txt_err "File v${NEWVER}.tar.gz still doesn't look to exist ..."
        txt_err "Manual intervention required ..."
        CR1
        txt_info "Path here :"
        ls -lah "${ROOT}" | grep -E *.tar.gz
        CR1
        GAME_OVER
      else
        txt_ok "File v${NEWVER}.tar.gz is available in $(pwd)"
      fi
    else
      SL1
      txt_err "Netbox v${NEWVER} either doesn't exist or URL is unavailable ..."
      SL1; CR1
      txt_info "Refer to website for Releases:"
      txt_url "${URLR}"
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
    unset COUNT
  break
  fi
done
SL1


CR2
txt_header "----- DOWNLOAD COMPLETE -----"
SL2; CR2


#################################################################################################


txt_header "----- CHECK EXISTING NETBOX INSTALL -----"
SL1; CR2

WILL_YOU_CONTINUE

txt_warn "Script only supports symlink installs at this stage."
SL1; CR1

txt_info "Checking directories ..."

if ! [ -d $NBROOT ]; then
  if [[ $INSTALL = new ]]; then
    SL1
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
    txt_ok "Netbox dir is symbolically linked."
  else
    txt_err "Exception : Netbox dir exists but undetermined install type ..."
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
  txt_info "Path ${NBPATH} looks to exist already ..."
else
  txt_info "Extracting tar file to ${NBPATH} ..."
  tar -xzf "v${NEWVER}.tar.gz"
  SL1
  txt_ok "... Extracted"
fi
SL1; CR1

      #=# PLACEHOLDER REMINDER : As above.
if ! [ -d "${NBPATH}" ]; then
  txt_err "Path ${NBPATH} still doesn't look to exist ..."
  txt_err "Manual intervention required ..."
  txt_norm "Path here :"
  ls -lah "${ROOT}" | grep netbox
  CR1
  GAME_OVER
fi
CR1

txt_header "----- NETBOX INSTALL CHECK COMPLETE -----"
SL2; CR2


#################################################################################################


     #=# PLACEHOLDER REMINDER : Revise code. Some redundant, at least at this stage.
#elif [[ $INSTALL = git ]]; then
#  txt_err "Git installs not yet supported. Script cannot continue ..."
#  GAME_OVER
#if [[ $INSTALL = upgrade ]] || [[ $INSTALL = git ]]; then
if [[ $INSTALL = upgrade ]]; then
  txt_header "----- BACKUP FILES AND DATABASE -----"
  SL1; CR2
  
  WILL_YOU_CONTINUE

  TIME=$(date +%y-%m-%d_%H-%M)
  BKPATH="${BKROOT}/${TIME}"
  mkdir -p "${BKPATH}"
       #=# PLACEHOLDER REMINDER
       # File validations before copy, eg ldap
  txt_info "Copying files to backup dir ..."
  cp $NBROOT/local_requirements.txt "${BKPATH}/"
  cp $NBROOT/gunicorn.py "${BKPATH}/"
  cp $NBROOT/netbox/netbox/configuration.py "${BKPATH}/"
  cp $NBROOT/netbox/netbox/ldap_config.py "${BKPATH}/"
  txt_ok "Complete !"
  SL0; CR1
  txt_info "Backed up files here: "
  ls -lah "${BKPATH}"/
  SL2; CR2
       #=# PLACEHOLDER REMINDER
       # Come back to this for database backup etc
  #txt_warn "TODO: DATABASE BACKUP STUFF HERE"
  #txt_warn "TODO: TAR FILES HERE"
  #txt_warn "TODO: DELETE SOURCE FILES ONCE TAR'd"
  txt_header "----- BACKUP COMPLETE -----"
  unset TIME
fi


#################################################################################################


if [[ $INSTALL = upgrade ]]; then
  txt_header "----- UPGRADE COPY : FILES TO NEW NETBOX DIR -----"
  SL1; CR1
  
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



     #=# PLACEHOLDER REMINDER
# look to change to a while loop
# look to optimise counter vars


if [[ $INSTALL = upgrade ]]; then
  txt_header "----- UPGRADE : STOP NETBOX PROCESSES AND SYMLINK -----"
  txt_warn "Caution: This will make Netbox unavailable!"
  SL1; CR1
  
  WILL_YOU_CONTINUE

  OLDVER=$(ls -ld ${NBROOT} | awk -F"${NBROOT}-" '{print $2}' | cut -d / -f 1)
  if ! [[ $OLDVER =~ $REGEXVER ]]; then
    txt_warn "Discovered '${OLDVER}' doesn't look to be valid (eg 3.6.0) ..."
    SL1; CR1
    txt_info "Directory list here:"
    ls -ld "${NBROOT}" | grep netbox
    while true; do
      COUNT=0
      read -p "Please manually enter existing Netbox release (eg 3.6.0) and press Enter: " -r OLDVER
      if ! [[ $OLDVER =~ $REGEXVER ]]; then
        if [[ "${COUNT}" -gt 2 ]]; then
          txt_err "... Three incorrect attempts made."
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
  txt_info "Comparing current (${OLDVER}) to selection (${NEWVER})"
       #=# PLACEHOLDER REMINDER : Figure out this syntax. Needs more observation.
  #https://stackoverflow.com/questions/8654051/how-can-i-compare-two-floating-point-numbers-in-bash
  #if awk "BEGIN {exit !($NEWVER >= $OLDVER)}"; then
  #if [[ awk "BEGIN {exit !($NEWVER >= $OLDVER)}" == 1 ]]; then
  if [[ $(echo "${NEWVER} ${OLDVER}" | awk '{print ($1 >= $2)}') == 1 ]]; then
    txt_err "Current 'v${OLDVER}' same or newer than installing 'v${NEWVER}' !"
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
  txt_header "----- NEW : SETUP POSTGRESQL +++"
  SL2; CR2
  
  txt_info "Setting up Database ..."
  SL0
  
  WILL_YOU_CONTINUE

  txt_info "Installing packages '${PKG_PSQL}' ..."
  $PMGET $PKG_PSQL
  txt_ok "... done !"
  SL0; CR2
  
  set -e
  SL1; CR1
  
  # These options are here, but highly recommended to stick with the static vars.
  #read -p "Enter owner database name (suggested: 'netbox'): " -r DB_USER
  #read -p "Enter database name (suggested: 'netbox'): " -r DB_NAME
       #=# PLACEHOLDER REMINDER : Will make this a choice later.
  DB_USER=netbox
  DB_NAME=netbox
  
       #=# PLACEHOLDER REMINDER
       # Wrap this up in a loop to allow user to self-generate.
  DB_PASS=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 61 ; echo '')
  SC_PASS=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 61 ; echo '')
  
       #=# PLACEHOLDER REMINDER
       # Check for password file before autogeneration.
       # Should cover interrupted or incomplete installs.
  txt_info "Displaying password ..."
  SL1; CR1
  txt_warn "STORE PASSWORD SECURELY. DO NOT LOSE."
  SL0; CR1
  txt_info "Database Password"
  echo "$DB_PASS" | tee .DB_PASS
  
  txt_info "Netbox Secret Password"
  echo "$SC_PASS" | tee .SC_PASS
  SL0; CR1
  txt_warn "STORE PASSWORD SECURELY. DO NOT LOSE."
  SL0; CR1
  txt_ok "Password files '.DB_PASS' and '.SC_PASS' in '$(pwd)' dir"
  SL2; CR2
  
       #=# PLACEHOLDER REMINDER
       # Validate database creation, just in case another install is made.       
  txt_info "Modifying database."
  su postgres <<EOF
psql -c "CREATE DATABASE $DB_NAME;"
psql -c "CREATE USER $DB_USER WITH PASSWORD '$DB_PASS';"
psql -c "ALTER DATABASE $DB_NAME OWNER TO $DB_USER;"
EOF
       #=# PLACEHOLDER REMINDER
       # Work on version syntax to qualify this.  
  if [[ $POSTGRES = fifteeeeen ]]; then
    ##The next two commands are needed on PostgreSQL 15 and later
    su postgres <<EOF
psql -c "\connect $DB_USER";
psql -c "GRANT CREATE ON SCHEMA public TO $DB_USER";
EOF
    SL1;CR1

     #=# PLACEHOLDER REMINDER
     # Perhaps integrate this in to script.

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
  fi
  txt_ok "... done !"
  SL1; CR1

  txt_header "----- POSTGRES SETUP COMPLETE -----"
  SL2
fi

#################################################################################################


if [[ $INSTALL = new ]]; then
  txt_header "----- NEW : SETUP REDIS -----"
  
  WILL_YOU_CONTINUE
  
  txt_info "Installing packages for Redis ..."
  CR1
  $PMGET $PKG_REDIS
  SL0; CR1
  
  txt_ok "... done !"
  SL0; CR1
  
  txt_info "Redis checks..."
  SL1; CR1
  
       #=# PLACEHOLDER REMINDER
       # Add auto-validation to capture the PONG to the ping. Consider intervention if not.
  redis-server -v
  redis-cli ping
  txt_ok "... done"
  SL2; CR2
  
  txt_header "----- REDIS SETUP DONE -----"
  SL2; CR2
fi


#################################################################################################


if [[ $INSTALL = new ]]; then
  txt_header "----- NEW : NETBOX SETUP -----"
  SL0; CR1
  
  WILL_YOU_CONTINUE
  SL0; CR2
  
  txt_info "Installing packages ..."
  $PMGET $PKG_NETBOX
  SL0; CR1
  txt_ok "... done !"
  
  ln -sfn "${NBROOT}-${NEWVER}"/ "${NBROOT}"

  txt_info "Setting permissions on dirs ..."
       #=# PLACEHOLDER REMINDER
       # Make more robust I guess
  if [[ $PMGR = apt ]]; then
    adduser --system --group netbox
    chown --recursive netbox $NBMEDIA
    chown --recursive netbox $NBREPORTS
    chown --recursive netbox $NBSCRIPTS
  elif [[ $PMGR = yum ]]; then
    groupadd --system netbox
    adduser --system -g netbox netbox
    chown --recursive netbox /opt/netbox/netbox/media/
    chown --recursive netbox /opt/netbox/netbox/reports/
    chown --recursive netbox /opt/netbox/netbox/scripts/
  else
    txt_err "Exception. Distro not determined"
    GAME_OVER
  fi
  SL1; CR1
  txt_ok "... done !"

  
  cd "${NBROOT}/netbox/netbox/"
  cp configuration_example.py configuration.py
  
       #=# PLACEHOLDER REMINDER :
       # Validate files before editing (for concurrent runs).
       #
       # Also evaluate making this user input choice using the likes of nano.
       
  txt_info "Updating configuration.py ..."
  SL1; CR1
  
  txt_info "Before : ALLOWED_HOSTS"
  printf '%b\n' "$(cat configuration.py | grep -F "ALLOWED_HOSTS = [" | grep -v Example)"
    sed -i "s|ALLOWED_HOSTS = \[\]|ALLOWED_HOSTS = \['*'\]|g" configuration.py
  txt_info "After : ALLOWED_HOSTS"
  printf '%b\n' "$(cat configuration.py | grep -F "ALLOWED_HOSTS = [" | grep -v Example)"
  SL1; CR1

  txt_info "Before : Netbox Database User"
  printf '%b\n' "$(cat configuration.py | grep -F "'USER': '")"
    sed -i "s|'USER': '',|'USER': '$DB_USER',|g" configuration.py
  txt_info "After : Netbox Database User"
  printf '%b\n' "$(cat configuration.py | grep -F "'USER': '")"
  SL1; CR1

  txt_info "Before : Password for User"
  printf '%b\n' "$(cat configuration.py | grep -F "'PASSWORD': '" | grep -F "PostgreSQL")"
    sed -i "s|'PASSWORD': '',           # PostgreSQL password|'PASSWORD': '$DB_PASS',           # PostgreSQL password|g" configuration.py
  txt_info "After : Password for User"
  printf '%b\n' "$(cat configuration.py | grep -F "'PASSWORD': '" | grep -F "PostgreSQL")"
  SL1; CR1

  txt_info "Before : Secret Pass for Netbox"
  printf '%b\n' "$(cat configuration.py | grep -F "SECRET_KEY = '")"
    sed -i "s|SECRET_KEY = ''|SECRET_KEY = '$SC_PASS'|g" configuration.py
  txt_info "After : Secret Pass for Netbox"
  printf '%b\n' "$(cat configuration.py | grep -F "SECRET_KEY = '")"
  SL1; CR2
  txt_ok "... done"
  SL0; CR2
  
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
  # SL1; CR2
  
       #=# PLACEHOLDER REMINDER
       # Code duplicity with upgrade section above. Look to consolidate
  txt_info "Run Netbox upgrade script ..."
  SL2; CR2
  bash "${NBROOT}/upgrade.sh"
  SL2; CR2
  txt_ok "... done"
  SL0; CR1
  
  txt_info "Create Superuser"
  nbmg createsuperuser
  SL1; CR1
  txt_ok "... done"
       #=# PLACEHOLDER REMINDER
       # Evaluate this not being missed on a 3.4+ to 3.6 upgrade.
       # Will need to pull it out of the if conditional.
  if [[ $(echo "${NEWVER} 3.6.0" | awk '{print ($1 >= $2)}') == 1 ]]; then
    txt_info "Selection (${NEWVER}) or newer than 3.6.0 requires Dulwich for Git data source function."
    txt_info "Adding dulwich to local_requirements.txt"
    echo 'dulwich' >> "${NBROOT}/local_requirements.txt"
    SL1; CR1
    txt_ok "... done"
  fi
    
  txt_info "Adding Housekeeping to cron tasks"
  ln -s "${NBROOT}/contrib/netbox-housekeeping.sh" /etc/cron.daily/netbox-housekeeping
  SL0
  txt_ok "... done"
  
  txt_header "----- NETBOX SETUP DONE -----"
  SL2
fi


#################################################################################################

if [[ $INSTALL = new ]]; then
  txt_header "----- NEW : GUNICORN SETUP -----"
  SL0; CR1
  
  WILL_YOU_CONTINUE
  SL0; CR1

  txt_info "Copying files to set Netbox as service ..."
  cp "${NBROOT}/contrib/gunicorn.py" "${NBROOT}/gunicorn.py"
  cp -v "${NBROOT}/contrib/"*".service" "/etc/systemd/system/"
  SL1; CR1
  txt_ok "... done"
  SL0; CR2

  txt_info "Starting Netbox processes..."
  systemctl daemon-reload
  systemctl start netbox netbox-rq
  systemctl enable netbox netbox-rq
       #=# PLACEHOLDER REMINDER
       # Add service start validation. Perhaps make a counter loop.
  # systemctl status netbox.service
  SL2; CR1
  txt_ok "...done."
  SL1; CR1
  
  txt_header "----- GUNICORN SETUP DONE -----"
  SL2
fi


#################################################################################################

     #=# PLACEHOLDER REMINDER
     # Make this a choice between Nginx and Apache
     # https://docs.netbox.dev/en/stable/installation/5-http-server/

if [[ $INSTALL = new ]]; then
  NB_DNS=netbox.local
  WWW=nginx

  txt_info "Installing packages ..."
  $PMGET $PKG_WWW
  SL0; CR1
  txt_ok "... done !"
  SL1; CR1

  if [[ "${WWW}" = nginx ]]; then
    txt_header "----- SETUP NGINX -----"
    SL0

    WILL_YOU_CONTINUE
  
       #=# PLACEHOLDER REMINDER
       # Place options, including use certbot to properly do this
    txt_info "Creating certs..."
    SL2; CR1

    openssl req -new -newkey rsa:4096 -days 365 -nodes -x509 \
    -subj "/C=NZ/ST=Denial/L=RiverIn/O=Ejypt/CN=${NB_DNS}" \
    -keyout /etc/ssl/private/netbox.key \
    -out /etc/ssl/certs/netbox.crt

    txt_ok "... done"
    SL1; CR1
  
    cp $NBROOT/contrib/nginx.conf /etc/nginx/sites-available/netbox
  
       #=# PLACEHOLDER REMINDER
       # Make this interactive. Consider defining with others at start and then having a match conditional here.
    txt_info "Adjusting ${WWW} config server name"
    SL0: CR1

    txt_info "Before:"
    printf '%b\n' "$(cat /etc/nginx/sites-available/netbox | grep -F server_name)"
      sed -i "s|netbox.example.com|$NB_DNS|g" /etc/nginx/sites-available/netbox
    SL1
    txt_info "After:"
    printf '%b\n' "$(cat /etc/nginx/sites-available/netbox | grep -F server_name)"
    SL0; CR1
    txt_ok "... done"
    SL1; CR2

    txt_info "Cleaning up..."
    rm /etc/nginx/sites-enabled/default
    ln -s /etc/nginx/sites-available/netbox /etc/nginx/sites-enabled/netbox

    #=# PLACEHOLDER REMINDER
    # Add start validation
    systemctl restart nginx
  
  fi
  txt_header "----- NGINX SETUP DONE -----"
  SL2
fi

#################################################################################################

## PLACEHOLDER REMINDER : Perform this process.
# txt_header "----- SETUP SSL CERTIFICATES -----"


#################################################################################################


txt_header "----- RUNNING SCRIPT AND STARTING NETBOX -----"
SL1; CR2
     #=# PLACEHOLDER REMINDER
     # This applies to new/git installs also. Consider conolidating code.
txt_info "Running the Netbox upgrade script..."
     #=# PLACEHOLDER REMINDER : add git types to ifs
if ! [[ $INSTALL = new ]] || [[ $INSTALL = git_new ]]; then
  txt_warn "Likely no going back after this !"
  SL0; CR2
  WILL_YOU_CONTINUE
  SL1; CR2
fi

bash "${NBROOT}/upgrade.sh" | tee "upgrade_$(date +%y-%m-%d_%H-%M).log"
SL1; CR1
txt_ok "... done"
SL1; CR2

txt_info "Starting Netbox processes ..."
SL0; CR1
     #=# PLACEHOLDER REMINDER
     # Make this a better choice.
WILL_YOU_CONTINUE
SL1; CR1
     #=# PLACEHOLDER REMINDER
     # Add process start validation.
systemctl start netbox netbox-rq
SL0; CR1
txt_ok "Processes started"
SL2
# systemctl status netbox netbox-rq

txt_header "----- NETBOX RUNNING -----"
SL2

# FINISHED !!
endTime=$(date +%s)
say "Script completed in $(( endTime - startTime )) seconds!"
SL2; CR2
