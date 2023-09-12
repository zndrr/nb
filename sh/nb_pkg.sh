#!/bin/bash
if ! [ -e "global_vars.sh" ]; then echo ".sh Dependency missing! Exiting..." sleep 2; exit; fi
source global_vars.sh


PM=apt
#PM=yum
PMU="${PM} update"
PMGET="${PM} install -y"

PKG_SCRIPT="wget tar"
PKG_GIT="git"
PKG_PSQL="postgresql"
PKG_REDIS="redis-server"
PKG_NETBOX="python3 python3-pip python3-venv python3-dev build-essential libxml2-dev libxslt1-dev libffi-dev libpq-dev libssl-dev zlib1g-dev"
PKG_WWW="nginx"

txt_info "Package update"
PMU
txt_info "Installing Packages"
$PMGET $PKG_SCRIPT
$PMGET $PKG_GIT
$PMGET $PKG_PSQL
$PMGET $PKG_REDIS
$PMGET $PKG_NETBOX
$PMGET $PKG_WWW
