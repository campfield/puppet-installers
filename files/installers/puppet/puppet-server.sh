#!/bin/bash

export SOURCE_DIRECTORY=$(dirname $(realpath $0))

source ${SOURCE_DIRECTORY}/boilerplate.sh


echo "Executiong [$0]"

echo ''
echo 'Puppet mode: [server].'
echo -e "\tServer: [$PUPPET_SERVER]."
echo -e "\tDatabase: [$DB_ENABLE]."
echo -e "\tWait for Cert [$WAIT_FOR_CERT]."
echo -e "\tAutosign [${CERT_AUTOSIGN}]."
echo -e "\tEnvironment [$ENVIRONMENT]."
echo -e "\tProvider [$PROVIDER]."
echo ''

$SUDO apt-get update

$SUDO apt-get -y install \
  crudini \
  less \
  nano \
  screen

#
# Notes:
#  We call 'service' instead of 'systemctl' when starting a service as if this is
#  installing in a container (e.g., Singularity)
#


$SUDO apt-get -y install \
  hiera-eyaml \
  reclass

if [[ $PROVIDER == 'puppet' ]]; then
  $SUDO apt-get -y install \
    puppetserver
elif [[ $PROVIDER == 'openvox' ]]; then
  $SUDO apt-get -y install \
    ${PROVIDER}-server
fi

export CODE_DIRECTORY='/etc/puppetlabs/code'
export ENVIRONMENT_DIRECTORY="${CODE_DIRECTORY}/environments"
export EYAML_KEYS_DIRECTORY='/etc/puppetlabs/puppetserver/keys'
export PUPPETFILESERVER_DIRECTORY='/var/puppetlabs/puppetserver/fileserver'
export EYAML_PATH="${BIN_DIRECTORY}/eyaml"
export PUPPETSERVER_PATH="${BIN_DIRECTORY}/puppetserver"
export PUPPETDB_DATA_DIRECTORY=/opt/puppetlabs/server/data/puppetdb/
export GEM_LIST='ipaddress'
export PATH=$BIN_DIRECTORY:$PATH


#
# Prevent the puppet agent from running within the environment
#  unless we trigger it - especially as the environment is 1/2 way set up.
#
# ${BIN_DIRECTORY}/puppet agent --disable

for GEM in $GEM_LIST; do
  $SUDO ${PUPPETSERVER_PATH} gem install ${GEM} --no-document
done

if [[ -z $($SUDO ls "${EYAML_KEYS_DIRECTORY}/eyaml" 2>&1) ]]; then
  $SUDO mkdir -p  --mode=0700 -p "${EYAML_KEYS_DIRECTORY}/eyaml" || true
  $SUDO eyaml createkeys --pkcs7-public-key ${EYAML_KEYS_DIRECTORY}/default.pkcs7.crt --pkcs7-private-key ${EYAML_KEYS_DIRECTORY}/default.pkcs7.key
fi

#
#
# Write Puppet Configuration Files
#
#
$SUDO cat << _EOF_ > /etc/puppetlabs/puppet/puppet.conf

[main]
  ca_server = ${PUPPET_SERVER}
  certname = ${PUPPET_SERVER}
  client_cert_autosign = ${CERT_AUTOSIGN}
  server = ${PUPPET_SERVER}

[agent]
  certificate = ${PUPPET_SERVER}
  classfile = \$vardir/classes.txt
  daemonize = false
  graph = true
  localconfig = \$vardir/localconfig
  onetime = true
  pluginsync = true
  report = true
  show_diff = true
  usecacheonfailure = false
  waitforcert = ${WAIT_FOR_CERT}
  environment = ${ENVIRONMENT}

[server]
  autosign = ${CERT_AUTOSIGN}
  ca = true
  certificate = ${PUPPET_SERVER}
  certname = ${PUPPET_SERVER}
  external_nodes = ${CODE_DIRECTORY}/classifiers/${CLASSIFIER}
  node_terminus = exec

_EOF_
$SUDO chmod 644 /etc/puppetlabs/puppet/puppet.conf
$SUDO chown puppet:puppet /etc/puppetlabs/puppet/puppet.conf


if [[ -d ${ENVIRONMENT_DIRECTORY}/${ENVIRONMENT} ]]; then

$SUDO cat << _EOF_ > ${ENVIRONMENT_DIRECTORY}/${ENVIRONMENT}/environment.conf

# Puppet module search path orderings.
# Manifests: Location of Roles and Profiles
# Custom: Developed in-house.
# Localized: Modified another developer's module.
# Upstream: Module developed by an external party.

modulepath = ./manifests/projects:./modules/projects:./modules/custom:./modules/localized:./modules/upstream:\$basemodulepath

_EOF_

fi

mkdir -p ${CODE_DIRECTORY}/classifiers/

cat << _EOF_ > ${CODE_DIRECTORY}/classifiers/enc.sh
echo
_EOF_



mkdir -p ${CODE_DIRECTORY}/hiera/
mkdir -p ${ENVIRONMENT_DIRECTORY}/$ENVIRONMENT/

$SUDO chmod -R ugo+rx ${CODE_DIRECTORY}/classifiers ${CODE_DIRECTORY}/hiera ${ENVIRONMENT_DIRECTORY}
$SUDO chown -R puppet:puppet ${CODE_DIRECTORY}/classifiers ${CODE_DIRECTORY}/hiera ${ENVIRONMENT_DIRECTORY}

#
#
#
#
#

$SUDO cat << _EOF_ > /etc/puppetlabs/puppetserver/conf.d/ca.conf
certificate-authority: {
  # allow CA to sign certificate requests that have subject alternative names.
  allow-subject-alt-names: true

  # allow CA to sign certificate requests that have authorization extensions.
  allow-authorization-extensions: true

  # enable the separate CRL for Puppet infrastructure nodes
  enable-infra-crl: true
}
_EOF_
$SUDO chmod 644 /etc/puppetlabs/puppetserver/conf.d/ca.conf
$SUDO chown puppet:puppet /etc/puppetlabs/puppetserver/conf.d/ca.conf



#
#
# Set up Puppet server CA
#  Watch out - we are blindly removing the old SSL items.
#
#

$SUDO service puppetserver stop
$SUDO /bin/rm -rf /etc/puppetlabs/puppet/ssl /etc/puppetlabs/puppetserver/ca
$SUDO ${PUPPETSERVER_PATH} ca setup --conf /etc/puppetlabs/puppet/puppet.conf


#
#
# Configure Puppet-internal fileserver
#
#

for DIRECTORY in accounts installers misc pki software; do
  if [[ ! -d "$DIRECTORY" ]]; then
    $SUDO mkdir --mode=0750 -p "${DIRECTORY}"
    $SUDO chown -R puppet:puppet "${DIRECTORY}"
  fi
done


$SUDO cat << _EOF_ > /etc/puppetlabs/puppet/fileserver.conf

#
# Items specific to users such as authorized_keys, bashrc, and bin/ dirs.
#
[fileserver_accounts]
path ${PUPPET_FILESERVER_DIRECTORY}/accounts
allow *

#
# Installers such as RPM, DEB, EXE files, etc.
#
[fileserver_installers]
path ${PUPPET_FILESERVER_DIRECTORY}/installers
allow *

#
# Where does it belong?  I don't know.  Lets put it here then.
#
[fileserver_misc]
path ${PUPPET_FILESERVER_DIRECTORY}/misc
allow *

#
# PKI items such as certificate chains, Java Keystores, etc.
#  Remember - this is unencrypted data - don't put private keys here
#  unless you really don't care about their security.
#
[fileserver_pki]
path ${PUPPET_FILESERVER_DIRECTORY}/pki
allow *

#
# Scripts, non-packaged binaries, Docker files, Singularity images, etc.
#
[fileserver_software]
path ${PUPPET_FILESERVER_DIRECTORY}/software
allow *

_EOF_
$SUDO chmod 644 /etc/puppetlabs/puppet/fileserver.conf
$SUDO chown puppet:puppet /etc/puppetlabs/puppet/fileserver.conf



#
#
# Set up Pupperserver Hiera lookup manifests
#
#

$SUDO cat << _EOF_ > /etc/puppetlabs/code/hiera.yaml
---

version: 5
defaults:
  datadir: ${ENVIRONMENT_DIRECTORY}/hiera
  data_hash: yaml_data

hierarchy:
  - name: "Hiera encrypted YAML (eyaml) files."
    path: "default.eyaml"
    lookup_key: eyaml_lookup_key
    options:
      pkcs7_private_key: ${EYAML_KEYS_DIRECTORY}/default.pkcs7.key
      pkcs7_public_key:  ${EYAML_KEYS_DIRECTORY}/default.pkcs7.crt

  - name: "Hiera YAML lookup hierarchy w/ higher being more authorative values."
    paths:
    - "hosts/%{facts.fqdn}.yaml"
    - "roles/%{::role}.yaml"
    - "hostgroups/%{::hostgroup}.yaml"
    - "operatingsystems/%{::operatingsystem}/%{facts.os.distro.release.major}.yaml"
    - "operatingsystems/%{::operatingsystem}.yaml"
    - "dynamic.yaml"
    - "default.yaml"

_EOF_
$SUDO chmod 644 /etc/puppetlabs/code/hiera.yaml
$SUDO chown puppet:puppet /etc/puppetlabs/code/hiera.yaml

if [[ $DB_ENABLE == 'true' ]]; then
echo KKKKKKK

  source ${SOURCE_DIRECTORY}/puppet-db.sh
echo LLLLLL
exit
fi


for SERVICE_NAME in puppetserver; do
  $SUDO systemctl enable $SERVICE_NAME
  $SUDO systemctl restart $SERVICE_NAME
done


if [[ $CONTAINER == 'false' ]]; then
  $SUDO ufw allow puppet
fi

