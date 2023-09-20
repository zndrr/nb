#!/bin/bash

# Source definitions
if [ ! -e "env_global.sh" ]; then printf '%b\n' "env .sh Dependency missing! Exiting..." sleep 2; exit; fi
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
#  Updated: 2023-07-16
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
CHECK_ROOT
CHECK_PKG_MGR

      #=# PLACEHOLDER REMINDER
      # To remove
#ROOT_CHECK
#PKG_MGR_CHECK



#################################################################################################

# Local path variables
      #=# PLACEHOLDER REMINDER : Change these to choices, with defaults.
osRoot=/opt
nbRoot=$osRoot/netbox
bkRoot=$osRoot/nb/backup

      #=# PLACEHOLDER REMINDER : Revisit
      # These I want to suggest. Backups and external files would be best living outside Netbox path.
#nbMedia=$osRoot/nb/media/
#nbReports=$osRoot/nb/reports/
#nbScripts=$osRoot/nb/scripts/

nbMedia=$nbRoot/netbox/media/
nbReports=$nbRoot/netbox/reports/
nbScripts=$nbRoot/netbox/scripts/

# Local Netbox functions
nbv() { source $nbRoot/venv/bin/activate; }
nbmgr() { nbv; python3 $nbRoot/netbox/manage.py "$1"; }
nbs() { nbv; python3 $nbRoot/netbox/manage.py nbshell; }


# Variables to validate Netbox release version inputs etc.
# Check and update periodically as newer releases roll around.
regexVer="^[0-9].[0-9].[0-9]{1,2}$"
minor1=3.6.0
minor2=3.5.0
major1=3.0.0


# URL variables for text output. Update if they change.
urlUpg="https://docs.netbox.dev/en/stable/installation/upgrading/"
urlNew="https://docs.netbox.dev/en/stable/installation/"
urlRel="https://github.com/netbox-community/netbox/releases/"
urlCty="https://github.com/netbox-community/"


# Packages in various stages.
     #=# PLACEHOLDER REMINDER : Plan on making this interactive.

pkgScript="wget tar nano curl"

if [[ $PMGR = apt ]] || [[ $PMGR = yum ]]; then
  pkgGit="git"
  pkgWww="nginx"
  if [[ $PMGR = apt ]]; then
    pkgPsql="postgresql"
    pkgRedis="redis-server"
    pkgNetbox="python3 python3-pip python3-venv python3-dev build-essential libxml2-dev libxslt1-dev libffi-dev libpq-dev libssl-dev zlib1g-dev"
    pkgLdap="libldap2-dev libsasl2-dev libssl-dev"
  elif [[ $PMGR = yum ]]; then
    pkgPsql="postgresql-server"
    pkgRedis="redis"
    pkgNetbox="gcc libxml2-devel libxslt-devel libffi-devel libpq-devel openssl-devel redhat-rpm-config"
    pkgLdap="openldap-devel python3-devel"
  fi
else
  t_err "Exception. Distro not determined !"
  GAME_OVER
fi

SL1; CR2



#################################################################################################


# Check critical packages installed. Exit if not.
t_info "Running a package update ... "
$PMUPD
SL1; CR2
t_ok "... done."


t_info "Checking script package dependencies ..."
CHECK_PKG $pkgScript
t_ok "... done. Continuing ..."
SL1; CR2



#################################################################################################
# Make deterministic choice of install type


t_head "Choose your install type:"
SL1
while true; do
  read -p "(u)pgrade | (n)ew | (g)it | (q)uit : " -r -n 1 option
  CR1
  case $option in
    u|U) 
      insType=upgrade
      break;;
    n|N) 
      insType=new
      break;;
    g|G)
      # Script will reload here; you won't qualify the second condition below.
      insType=git
      t_err "Git install not supported yet. Try again ..."
      START_OVER;;
    q|Q)
      GAME_OVER;;
    *)
      t_warn "Invalid option '${REPLY}'. Try again ..."; CR1
  esac
done

      #=# PLACEHOLDER REMINDER
##### This is in place for when I explore git install method.
#! if [[ $insType = git ]]; then
#!   t_head "What type of Git install?"
#!   SL1
#!   while true; do
#!     read -p "Git - (u)pgrade | (n)ew | (q)uit : " -r -n 1 option2
#!     CR1
#!     case $option2 in
#!       u|U)
#!         insType=git-upgrade
#!         break;;
#!       n|N)
#!         insType=git-new
#!         break;;
#!       q|Q)
#!         GAME_OVER;;
#!       *)
#!         t_warn "Invalid option '${REPLY}'. Try again ..."; CR1
#!     esac
#!   done
#! fi

t_info "Will proceed with ${insType} install ..."

SL1


#################################################################################################
# Start script here

t_head "----- DOWNLOADING NETBOX RELEASE -----"

t_info "Moving in to ${osRoot} directory ..."
mkdir -p "${osRoot}"
cd "${osRoot}"

SL2

      #=# PLACEHOLDER REMINDER
      # Optimise this loop. Bit of redundancy in checks.

COUNT=0
while true; do
  CR1
  read -p "Please enter desired Netbox release (eg 3.6.0) and press Enter: " -r newVer
  urlDl="https://github.com/netbox-community/netbox/archive/v${newVer}.tar.gz"
  if [[ !  $newVer =~ $regexVer ]]; then
    if [[ "${COUNT}" -gt 2 ]]; then
      t_err "... Too many incorrect attempts made."
      GAME_OVER
    fi
    t_warn "Selection '${newVer}' not valid (eg 3.6.0). Try again ..."
    ((COUNT++))
    SL1
    continue
  elif [ -e "${osRoot}/v${newVer}.tar.gz" ]; then
    t_ok "File looks to exist already. Download not required ..."
    break
  elif [ ! -e "${osRoot}/v${newVer}.tar.gz" ]; then
    if [ $(SW_VER ${newVer}) -lt $(SW_VER ${major1}) ]; then
      t_err "Selection (${newVer}) at least 1 MAJOR release behind project (${major1}) !"
      t_err "Selection too old! Select again ..."
      continue
    elif [ $(SW_VER ${newVer}) -lt $(SW_VER ${minor2}) ]; then
      t_warn "Selection (${newVer}) at least 2 minor releases behind project (${minor1}) !"
      t_warn "Highly recommended to select a newer release!"
    elif [ $(SW_VER ${newVer}) -lt $(SW_VER ${minor1}) ]; then
      t_warn "Selection '${newVer}' at least 1 minor release behind project '${minor1}' !"
    SL1
    fi
    t_info "Checking availability ..."
    if wget --spider "${urlDl}" 2>/dev/null; then
      t_ok "Release v${newVer} download found."
      SL1; CR1
      t_info "Downloading ..."
      SL1
      wget -q --show-progress "${urlDl}" -P "${osRoot}/" --no-check-certificate
      SL1
      t_ok "... Download complete!"
      # Double-checking tarball exists
      t_info "Confirming file present after download ..."
      SL0; CR1
      if [ ! -e "${osRoot}/v${newVer}.tar.gz" ]; then
        t_err "File v${newVer}.tar.gz still doesn't look to exist ..."
        t_err "Manual intervention required ..."
        CR1
        t_info "Path here :"
        ls -lah "${osRoot}" | grep -E *.tar.gz
        CR1
        GAME_OVER
      else
        t_ok "File v${newVer}.tar.gz is available in ${osRoot}"
      fi
    else
      SL1
      t_err "Netbox v${newVer} either doesn't exist or URL is unavailable ..."
      SL1; CR1
      t_info "Refer to website for Releases:"
      t_url "${urlRel}"
      if [[ $insType = new ]]; then
        t_info "Also refer to the below for new install process ..."
        t_url "${urlNew}"
      elif [[ $insType = upgrade ]]; then
        t_info "Also refer to the below for upgrade process ..."
        t_url "${urlUpg}"
      fi
      t_info "Or visit Netbox Community here ..."
      t_url "${urlCty}"
      GAME_OVER
    fi
    unset COUNT
  break
  fi
done
SL1

CR2
touch $SCRIPT_ROOT/.NB_DOWNLOAD
t_head "----- DOWNLOAD COMPLETE -----"
SL2; CR2


#################################################################################################


t_head "----- CHECK FOR EXISTING NETBOX INSTALL -----"
SL1; CR2

WILL_YOU_CONTINUE

t_warn "Script only supports symlink installs at this stage."
SL1; CR1

t_info "Checking directories ..."

if [[ ! -d $nbRoot ]] && [[ $insType = upgrade ]]; then
  SL1
  t_err "Unexpected outcome. Did you mean to select New install ..."
  START_OVER
elif [[ -d $nbRoot ]]; then
  if [[ -e $nbRoot/.git ]]; then
         #=# PLACEHOLDER REMINDER
         # ADD GIT COMMANDS IN HERE
    t_warn "Netbox directory exists but appears to be a Git install ..."
    t_err "Git installs not yet supported. Script cannot continue ..."
    GAME_OVER
  elif [[ -L $nbRoot ]]; then
    t_ok "Netbox dir is symbolically linked."
  else
    t_err "Exception : Netbox dir exists but undetermined install type ..."
    t_err "Script cannot continue ..."
    GAME_OVER
  fi
fi

SL2

# Will extract tar file as long as destination doesn't exist.
nbPath=$nbRoot-$newVer

     #=# PLACEHOLDER REMINDER
     # Look to change this to a while loop
if [ -d "${nbPath}" ]; then
  t_info "Path ${nbPath} looks to exist already ..."
else
  t_info "Extracting tar file to ${nbPath} ..."
  tar -xzf "v${newVer}.tar.gz"
  SL1
  t_ok "... Extracted"
fi
SL1; CR1

      #=# PLACEHOLDER REMINDER : As above.
if [ ! -d "${nbPath}" ]; then
  t_err "Path ${nbPath} still doesn't look to exist ..."
  t_err "Manual intervention required ..."
  t_norm "Path here :"
  ls -lah "${osRoot}" | grep netbox
  CR1
  GAME_OVER
fi
CR1

t_head "----- NETBOX INSTALL CHECK COMPLETE -----"
SL2; CR2


#################################################################################################


     #=# PLACEHOLDER REMINDER : Revise code. Some redundant, at least at this stage.

#if [ ! -e $SCRIPT_ROOT/.NB_UPG_BACKUP ]; then
  
  nbConfPy=$nbRoot/netbox/netbox/configuration.py
  nbGuni=$nbRoot/gunicorn.py
  nbLReq=$nbRoot/local_requirements.txt
  nbLdap=$nbRoot/netbox/netbox/ldap_config.py
  
  if [[ $insType = upgrade ]] || [[ $insType = git-upgrade ]]; then
    t_head "----- BACKUP FILES AND DATABASE -----"
    SL1; CR2
    
    WILL_YOU_CONTINUE
  
    t_info "Password needed for Database ..."
    if [[ -e $bkRoot/.DB_PASS ]]; then
      t_warn "Password file (.DB_PASS) detected. Loading content ..."
      DB_PASS=$(cat $bkRoot/.DB_PASS)
    elif [ $DB_PASS ]; then
      t_warn "Password already loaded in memory. Nothing to do ..."
    else
      read -p "Input password: " -r DB_PASS
    fi
    t_info "Password loaded."
    SL1; CR1

    bkTime=$(date +%y-%m-%d_%H-%M)
    bkPath="${bkRoot}/${bkTime}"
    mkdir -p "${bkPath}"
    t_info "Copying files to backup dir ..."
    if [ -f "${nbConfPy}" ]; then
      cp "${nbConfPy}" "${bkPath}/"
    else
      t_warn "Important file 'configuration.py' not found !"
    fi
    if [ -f "${nbLReq}" ]; then cp "${nbLReq}" "${bkPath}/"; fi
    if [ -f "${nbGuni}" ]; then cp "${nbGuni}" "${bkPath}/"; fi
    if [ -f "${nbLdap}" ]; then cp "${nbLdap}" "${bkPath}/"; fi
    t_ok "Complete !"
    SL0; CR1

    # Backup the Database
    t_info "Database Backup Started"
    dbStart=$(date +%s)
    PGPASSWORD=$DB_PASS pg_dump -h localhost -U $DB_USER netbox > ${bkPath}/db_$bkTime.sql
    dbEnd=$(date +%s)
    t_info "DB Backup finished in $((dbEnd-dbStart)) seconds."
    SL1; CR1

    t_info "Backed up files in '${bkPath}': "; SL0
    ls -lah "${bkPath}"/
    SL2; CR2
    
    t_info "Compressing backup as ${bkPath}.tar.gz and removing source directory ..."
    gzStart=$(date +%s)
    # use 'v' arg for verbose output.
    tar -czf ${bkRoot}/nb_backup_${bkTime}.tar.gz ${bkPath}
    #tar -cjf ${bkRoot}/nb_backup_${bkTime}.tar.bz2 ${bkPath}/ # bzip instead of gzip
    if [[ -f ${bkPath} ]]; then rm -r ${bkPath}; fi
    gzEnd=$(date +%s)
    SL1
    t_info "Backup compression done in $((gzEnd-gzStart)) seconds"

    unset bkTime
    touch $SCRIPT_ROOT/.NB_UPG_BACKUP
    t_head "----- BACKUP COMPLETE -----"
  fi
#fi


#################################################################################################

#if [[ ! -e $SCRIPT_ROOT/.NB_UPG_COPY ]]; then
  if [[ $insType = upgrade ]]; then
    t_head "----- UPGRADE COPY : FILES TO NEW NETBOX DIR -----"
    SL1; CR1
    
    WILL_YOU_CONTINUE
    
    t_info "Copying configuration files to new install ..."
    if [ -f "${nbConfPy}" ]; then
      cp "${nbConfPy}" "${nbRoot}-${newVer}/netbox/netbox/"
    else
      t_err "Important file 'configuration.py' not found !"
      t_warn "Manual intervention likely required. Chance of failure!"
      t_warn "Use the time at prompt to search ..."; SL0
      WILL_YOU_CONTINUE
    fi
    if [ -f "${nbLReq}" ]; then cp "${nbLReq}" "${nbRoot}-${newVer}/"; fi
    if [ -f "${nbGuni}" ]; then cp "${nbGuni}" "${nbRoot}-${newVer}/"; fi
    if [ -f "${nbLdap}" ]; then cp "${nbLdap}" "${nbRoot}-${newVer}/netbox/netbox/"; fi
          #=# PLACEHOLDER REMINDER
          # Look to make this conditional on user folder choice.
          # If outside Netbox Root, then no need to move around.
    if [ -d "${nbRoot}-${oldVer}/netbox/scripts/" ]; then cp -r "${nbRoot}-${oldVer}/netbox/scripts/" "${nbRoot}/netbox/"; fi
    if [ -d "${nbRoot}-${oldVer}/netbox/reports/" ]; then cp -r "${nbRoot}-${oldVer}/netbox/reports/" "${nbRoot}/netbox/"; fi  
    if [ -d "${nbRoot}-${oldVer}/netbox/media/" ]; then cp -pr "${nbRoot}-${oldVer}/netbox/media/" "${nbRoot}/netbox/"; fi
    SL1; CR1
    t_ok "... done! Files copied."
    SL1; CR1
    touch $SCRIPT_ROOT/.NB_UPG_COPY
    t_head "----- UPGRADE COPY : COMPLETE -----"
  fi
#fi

SL2


#################################################################################################



     #=# PLACEHOLDER REMINDER
# look to change to a while loop
# look to optimise counter vars

#if [[ ! -e $SCRIPT_ROOT/.NB_UPG_SYMLINK ]]; then
  if [[ $insType = upgrade ]]; then
    t_head "----- UPGRADE : STOP NETBOX PROCESSES AND SYMLINK -----"
    t_warn "Caution: This will make Netbox unavailable!"
    SL1; CR1
    
    WILL_YOU_CONTINUE
  
    oldVer=$(ls -ld ${nbRoot} | awk -F"${nbRoot}-" '{print $2}' | cut -d / -f 1)
    if [[ ! $oldVer =~ $regexVer ]]; then
      t_warn "Discovered '${oldVer}' doesn't look to be valid (eg 3.6.0) ..."
      SL1; CR1
      t_info "Directory list here:"
      ls -ld "${nbRoot}" | grep netbox
      while true; do
        COUNT=0
        read -p "Please manually enter existing Netbox release (eg 3.6.0) and press Enter: " -r oldVer
        if [[ ! $oldVer =~ $regexVer ]]; then
          if [[ "${COUNT}" -gt 2 ]]; then
            t_err "... Three incorrect attempts made."
            GAME_OVER
          fi
          t_warn "Selection '${oldVer}' format STILL not valid (eg 3.6.0). Try again ..."
          ((COUNT++))
          SL1
          continue
        elif [[ $oldVer =~ $regexVer ]]; then
          t_ok "Selection '${oldVer}' looks to be valid ..."
          break
        fi
      done
    fi
    CR1; SL1
    t_info "Comparing current '${oldVer}' to selection '${newVer}'"
    if [ $(SW_VER ${oldVer}) -ge $(SW_VER ${newVer}) ]; then
      t_err "Current 'v${oldVer}' same or newer than selected 'v${newVer}' !"
      GAME_OVER
    else
      t_ok "Selection '${newVer}' confirmed valid upgrade from '${oldVer}'"
    fi
  fi
  
  if [[ $insType = new ]]; then
    t_warn "New install selected. No processes to stop ..."
  elif [[ $insType = git ]]; then
    t_err "Git installs not yet supported. Script cannot continue ..."
    GAME_OVER
  elif [[ $insType = upgrade ]]; then
    systemctl stop netbox netbox-rq
    SL2
    CHECK_STOP netbox
    CHECK_STOP netbox-rq
    
    SL1
    t_info "Symlinking New ${newVer} to ${nbRoot}"
    ln -sfn "${nbRoot}-${newVer}"/ "${nbRoot}"
    SL0
    t_ok "... done."
  fi
  
  SL2
  touch $SCRIPT_ROOT/.NB_UPG_SYMLINK
  t_head "----- NETBOX SYMLINKING COMPLETE -----"
  SL2
#fi

#################################################################################################

#################################################################################################
# https://docs.netbox.dev/en/stable/installation/1-postgresql/

#if [[ ! -e $SCRIPT_ROOT/.NB_NEW_POSTGRES ]]; then
  if [[ $insType = new ]]; then
    t_head "----- NEW : SETUP POSTGRESQL -----"
    SL2; CR2
    
    t_info "Setting up Database ..."
    SL0
    
    WILL_YOU_CONTINUE
  
    t_info "Checking package dependencies for PostgreSQL ..."
    CHECK_PKG $pkgPsql
          #=# PLACEHOLDER REMINDER
    #$PMGET $pkgPsql
    t_ok "... done !"
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
         # Need some validation logic for password length, per Netbox requirements.
         # Have to consider escaping special characters for SED as well, or explore alternatives.
  
    t_info "Displaying password ..."
    SL1; CR1
    if [[ -e "${bkRoot}/.DB_PASS" ]] || [[ -e "${bkRoot}/.SC_PASS" ]]; then
      t_err "One or more files already exist !"
      t_err "Seems a possible failed or interrupted new install ..."
      WILL_YOU_CONTINUE
    else
      DB_PASS=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 61 ; echo '')
      SC_PASS=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 61 ; echo '')
      mkdir -p "${bkRoot}"
      t_warn "STORE PASSWORD SECURELY. DO NOT LOSE."
      SL0; CR1
      t_info "Database Password"
        t_norm "$DB_PASS" | tee "${bkRoot}/.DB_PASS"
      t_info "Netbox Secret Password"
        t_norm "$SC_PASS" | tee "${bkRoot}/.SC_PASS"
      SL0; CR1
      t_warn "STORE PASSWORD SECURELY. DO NOT LOSE."
      SL0; CR1
      t_ok "Password files '.DB_PASS' and '.SC_PASS' in '${bkRoot}' dir"
      SL2; CR2
    fi
         #=# PLACEHOLDER REMINDER
         # Validate database creation, just in case another install is made.       
    t_info "Modifying database."
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
    t_ok "... done !"
    SL1; CR1
  
    touch $SCRIPT_ROOT/.NB_NEW_POSTGRES
    t_head "----- POSTGRES SETUP COMPLETE -----"
    SL2
  fi
#fi

#################################################################################################

#if [[ ! -e $SCRIPT_ROOT/.NB_NEW_REDIS ]]; then
  if [[ $insType = new ]]; then
    t_head "----- NEW : SETUP REDIS -----"
    
    WILL_YOU_CONTINUE
    
    t_info "Checking package dependencies for Redis ..."
    CR1
    CHECK_PKG $pkgRedis
          #=# PLACEHOLDER REMINDER
    #$PMGET $pkgRedis
    SL0; CR1
    
    t_ok "... done !"
    SL0; CR1
    
    t_info "Redis checks..."
    SL1; CR1
    
         #=# PLACEHOLDER REMINDER
         # Add auto-validation to capture the PONG to the ping. Consider intervention if not.
    redis-server -v
    CR1
    redis-cli ping
    CR1
    t_ok "... done"
    SL2; CR2
    
    touch $SCRIPT_ROOT/.NB_NEW_REDIS
    t_head "----- REDIS SETUP DONE -----"
    SL2; CR2
  fi
#fi


#################################################################################################


#if [[ ! -e $SCRIPT_ROOT/.NB_NEW_SETUP ]]; then
  if [[ $insType = new ]]; then
    t_head "----- NEW : NETBOX SETUP -----"
    SL0; CR1
    
    WILL_YOU_CONTINUE
    SL0; CR2
    
    t_info "Checking package dependencies for Netbox ..."
    CHECK_PKG $pkgNetbox
          #=# PLACEHOLDER REMINDER
    #$PMGET $pkgNetbox
    SL0; CR1
    t_ok "... done !"
    
    ln -sfn "${nbRoot}-${newVer}"/ "${nbRoot}"
  
    t_info "Setting permissions on dirs ..."
         #=# PLACEHOLDER REMINDER
         # Make more robust I guess
    if [[ $PMGR = apt ]]; then
      adduser --system --group netbox
      chown --recursive netbox $nbMedia
      chown --recursive netbox $nbReports
      chown --recursive netbox $nbScripts
    elif [[ $PMGR = yum ]]; then
      groupadd --system netbox
      adduser --system -g netbox netbox
      chown --recursive netbox /opt/netbox/netbox/media/
      chown --recursive netbox /opt/netbox/netbox/reports/
      chown --recursive netbox /opt/netbox/netbox/scripts/
    else
      t_err "Exception. Distro not determined"
      GAME_OVER
    fi
    SL1; CR1
    t_ok "... done !"
  
    
    cd "${nbRoot}/netbox/netbox/"
    cp configuration_example.py configuration.py
    
         #=# PLACEHOLDER REMINDER :
         # Validate files before editing (for concurrent runs).
         #
         # Also evaluate making this user input choice using the likes of nano.
         
    t_info "Updating configuration.py ..."
    SL1; CR1
    
    t_info "Before : ALLOWED_HOSTS"
    printf '%b\n' "$(cat configuration.py | grep -F "ALLOWED_HOSTS = [" | grep -v Example)"
      sed -i "s|ALLOWED_HOSTS = \[\]|ALLOWED_HOSTS = \['*'\]|g" configuration.py
    t_info "After : ALLOWED_HOSTS"
    printf '%b\n' "$(cat configuration.py | grep -F "ALLOWED_HOSTS = [" | grep -v Example)"
    SL1; CR1
  
    t_info "Before : Netbox Database User"
    printf '%b\n' "$(cat configuration.py | grep -F "'USER': '")"
      sed -i "s|'USER': '',|'USER': '$DB_USER',|g" configuration.py
    t_info "After : Netbox Database User"
    printf '%b\n' "$(cat configuration.py | grep -F "'USER': '")"
    SL1; CR1
  
    t_info "Before : Password for User"
    printf '%b\n' "$(cat configuration.py | grep -F "'PASSWORD': '" | grep -F "PostgreSQL")"
      sed -i "s|'PASSWORD': '',           # PostgreSQL password|'PASSWORD': '$DB_PASS',           # PostgreSQL password|g" configuration.py
    t_info "After : Password for User"
    printf '%b\n' "$(cat configuration.py | grep -F "'PASSWORD': '" | grep -F "PostgreSQL")"
    SL1; CR1
  
    t_info "Before : Secret Pass for Netbox"
    printf '%b\n' "$(cat configuration.py | grep -F "SECRET_KEY = '")"
      sed -i "s|SECRET_KEY = ''|SECRET_KEY = '$SC_PASS'|g" configuration.py
    t_info "After : Secret Pass for Netbox"
    printf '%b\n' "$(cat configuration.py | grep -F "SECRET_KEY = '")"
    SL1; CR2
    t_ok "... done"
    SL0; CR2
    
    # Hint: Square brackets '[]' need escaping '\[\]'. Possibly others.
    # sed -i "s|VARIABLE1|VARIABLE2|g" file.txt
    
         #=# PLACEHOLDER REMINDER
         # Come back to this to possibly do conditionals/prompts
    
    ## OPTIONAL : This will change the media, reports and scripts paths. Here for reference. Might make it a choice later.
    
    #printf '%b\n' "$(cat configuration.py | grep -F "MEDIA_ROOT")"
      #sed -i "s|# MEDIA_ROOT = '/opt/netbox/netbox/media'|MEDIA_ROOT = '$nbMedia'|g" configuration.py
    #printf '%b\n' "$(cat configuration.py | grep -F "MEDIA_ROOT")"
    #
    #printf '%b\n' "$(cat configuration.py | grep -F "REPORTS_ROOT")"
      #sed -i "s|# REPORTS_ROOT = '/opt/netbox/netbox/reports'|REPORTS_ROOT = '$nbReports'|g" configuration.py
    #printf '%b\n' "$(cat configuration.py | grep -F "REPORTS_ROOT")"
    #
    #printf '%b\n' "$(cat configuration.py | grep -F "SCRIPTS_ROOT")"
      #sed -i "s|# SCRIPTS_ROOT = '/opt/netbox/netbox/scripts'|SCRIPTS_ROOT = '$nbScripts'|g" configuration.py
    #printf '%b\n' "$(cat configuration.py | grep -F "SCRIPTS_ROOT")"
    
    #t_warn "Clearing DB_PASS variable. Temporarily stored as file .DB_PASS in $(pwd)"
    #unset DB_PASS
  
    # Redundant since we do our own
    # t_info "Generate a secret key"
    # python3 ../generate_secret_key.py | tee .NB_PASS
    # SL1; CR2
    
         #=# PLACEHOLDER REMINDER
         # Code duplicity with upgrade section above. Look to consolidate
    t_info "Run Netbox upgrade script ..."
    SL2; CR2
    bash "${nbRoot}/upgrade.sh"
    SL2; CR2
    t_ok "... done"
    SL0; CR1
    
    t_info "Create Superuser"
    nbmgr createsuperuser
    SL1; CR1
    t_ok "... done"
         #=# PLACEHOLDER REMINDER
         # Evaluate this not being missed on a 3.4+ to 3.6 upgrade.
         # Will need to pull it out of the if conditional.
    if [[ $(echo "${newVer} 3.6.0" | awk '{print ($1 >= $2)}') == 1 ]]; then
      t_info "Selection (${newVer}) or newer than 3.6.0 requires Dulwich for Git data source function."
      t_info "Adding dulwich to local_requirements.txt"
      echo 'dulwich' >> "${nbRoot}/local_requirements.txt"
      SL1; CR1
      t_ok "... done"
    fi
      
    t_info "Adding Housekeeping to cron tasks"
    ln -s "${nbRoot}/contrib/netbox-housekeeping.sh" /etc/cron.daily/netbox-housekeeping
    SL0
    t_ok "... done"
    
    touch $SCRIPT_ROOT/.NB_NEW_SETUP
    t_head "----- NETBOX SETUP DONE -----"
    SL2
  fi
#fi

#################################################################################################


#if [[ ! -e $SCRIPT_ROOT/.NB_NEW_GUNI ]]; then
  if [[ $insType = new ]]; then
    t_head "----- NEW : GUNICORN SETUP -----"
    SL0; CR1
    
    WILL_YOU_CONTINUE
    SL0; CR1
  
    t_info "Copying files to set Netbox as service ..."
    cp "${nbRoot}/contrib/gunicorn.py" "${nbRoot}/gunicorn.py"
    cp -v "${nbRoot}/contrib/"*".service" "/etc/systemd/system/"
    SL1; CR1
    t_ok "... done"
    SL0; CR2
  
    t_info "Starting Netbox processes..."
    systemctl daemon-reload
    systemctl start netbox netbox-rq
    systemctl enable netbox netbox-rq
    # systemctl status netbox.service
    SL1; CR1
    CHECK_START netbox
    CHECK_START netbox-rq
    CHECK_URL $(hostname -i)
  
    
    SL2; CR1
    t_ok "...done."
    SL1; CR1
    
    touch $SCRIPT_ROOT/.NB_NEW_GUNI
    t_head "----- GUNICORN SETUP DONE -----"
    SL2
  fi
#fi

#################################################################################################

     #=# PLACEHOLDER REMINDER
     # Make this a choice between Nginx and Apache
     # https://docs.netbox.dev/en/stable/installation/5-http-server/

#if [[ ! -e $SCRIPT_ROOT/.NB_NEW_NGINX ]]; then
  if [[ $insType = new ]]; then
    nbHost=netbox.local
    webSrv=nginx
  
    t_info "Checking package dependencies for ${webSrv} ..."
    CHECK_PKG $pkgWww
          #=# PLACEHOLDER REMINDER
    #$PMGET $pkgWww
    SL0; CR1
    t_ok "... done !"
    SL1; CR1
  
    if [[ "${webSrv}" = nginx ]]; then
      t_head "----- SETUP NGINX -----"
      SL0
  
      WILL_YOU_CONTINUE
    
         #=# PLACEHOLDER REMINDER
         # Place options, including use certbot to properly do this
      t_info "Creating certs..."
      SL2; CR1
  
      openssl req -new -newkey rsa:4096 -days 365 -nodes -x509 \
      -subj "/C=NZ/ST=Denial/L=RiverIn/O=Ejypt/CN=${nbHost}" \
      -keyout /etc/ssl/private/netbox.key \
      -out /etc/ssl/certs/netbox.crt
  
      t_ok "... done"
      SL1; CR1
    
      cp $nbRoot/contrib/nginx.conf /etc/nginx/sites-available/netbox
    
         #=# PLACEHOLDER REMINDER
         # Make this interactive. Consider defining with others at start and then having a match conditional here.
      t_info "Adjusting ${webSrv} config server name"
      SL0; CR1
  
      t_info "Before:"
      printf '%b\n' "$(cat /etc/nginx/sites-available/netbox | grep -F server_name)"
        sed -i "s|netbox.example.com|$nbHost|g" /etc/nginx/sites-available/netbox
      SL1
      t_info "After:"
      printf '%b\n' "$(cat /etc/nginx/sites-available/netbox | grep -F server_name)"
      SL0; CR1
      t_ok "... done"
      SL1; CR2
  
      t_info "Cleaning up..."
      rm /etc/nginx/sites-enabled/default
      ln -s /etc/nginx/sites-available/netbox /etc/nginx/sites-enabled/netbox
  
      #=# PLACEHOLDER REMINDER
      # Add start validation
      systemctl restart nginx
      SL1; CR1
      
      CHECK_START nginx
      CHECK_URL $(hostname -i)
    fi
    touch $SCRIPT_ROOT/.NB_NEW_NGINX
    t_head "----- NGINX SETUP DONE -----"
    SL2
  fi
#fi


#################################################################################################

## PLACEHOLDER REMINDER : Perform this process.
# t_head "----- SETUP SSL CERTIFICATES -----"


#################################################################################################


t_head "----- RUNNING SCRIPT AND STARTING NETBOX -----"
SL1; CR2
     #=# PLACEHOLDER REMINDER
     # This applies to new/git installs also. Consider conolidating code.
t_info "Running the Netbox upgrade script..."
     #=# PLACEHOLDER REMINDER : add git types to ifs
if [[ ! $insType = new ]] || [[ ! $insType = git_new ]]; then
  t_warn "Likely no going back after this !"
  SL0; CR2
  WILL_YOU_CONTINUE
  SL1; CR2
fi

bash "${nbRoot}/upgrade.sh" | tee "upgrade_$(date +%y-%m-%d_%H-%M).log"
SL1; CR1
t_ok "... done"
SL1; CR2

t_info "Starting Netbox processes ..."
SL0; CR1
     #=# PLACEHOLDER REMINDER
     # Make this a better choice.
WILL_YOU_CONTINUE
SL1; CR1
     #=# PLACEHOLDER REMINDER
     # Add process start validation.
systemctl start netbox netbox-rq
SL0; CR1
CHECK_START netbox
CHECK_START netbox-rq
CHECK_URL $(hostname -i)
t_ok "Processes started"
SL2
# systemctl status netbox netbox-rq

t_head "----- NETBOX RUNNING -----"
SL2

# FINISHED !!
endTime=$(date +%s)


if [[ -e $SCRIPT_ROOT/.NB_DOWNLOAD ]]; then rm $SCRIPT_ROOT/.NB_DOWNLOAD; fi
if [[ -e $SCRIPT_ROOT/.NB_UPG_SYMLINK ]]; then rm $SCRIPT_ROOT/.NB_UPG_SYMLINK; fi
if [[ -e $SCRIPT_ROOT/.NB_NEW_REDIS ]]; then rm $SCRIPT_ROOT/.NB_NEW_REDIS; fi
if [[ -e $SCRIPT_ROOT/.NB_NEW_SETUP ]]; then rm $SCRIPT_ROOT/.NB_NEW_SETUP; fi
if [[ -e $SCRIPT_ROOT/.NB_NEW_GUNI ]]; then rm $SCRIPT_ROOT/.NB_NEW_GUNI; fi
if [[ -e $SCRIPT_ROOT/.NB_NEW_NGINX ]]; then rm $SCRIPT_ROOT/.NB_NEW_NGINX; fi
if [[ -e $SCRIPT_ROOT/.NB_UPG_COPY ]]; then rm $SCRIPT_ROOT/.NB_UPG_COPY; fi
if [[ -e $SCRIPT_ROOT/.NB_UPG_BACKUP ]]; then rm $SCRIPT_ROOT/.NB_UPG_BACKUP; fi

t_ok "Script completed in $(( endTime - startTime )) seconds!"

SL2; CR2
