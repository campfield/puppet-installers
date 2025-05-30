#!/bin/bash

export SOURCE_DIRECTORY=$(dirname $(realpath $0))

source ${SOURCE_DIRECTORY}/boilerplate.sh

echo ''
echo 'Puppet mode: [agent].'
echo -e "\tServer: [${PUPPET_SERVER}]."
echo -e "\tAutosign [${CERT_AUTOSIGN}]."
echo -e "\tDatabase: [${DB_ENABLE}]."
echo -e "\tEnvironment [${ENVIRONMENT}]."
echo -e "\tWait for Cert [${WAIT_FOR_CERT}]."
echo ''

$SUDO apt-get update

$SUDO apt-get -y install \
  ${PROVIDER}-agent

#
# Disable the puppet agent at the puppet software level.
#
/opt/puppetlabs/puppet/bin/puppet agent --disable;
$SUDO service puppet stop
$SUDO update-rc.d puppet disable

cat << _EOF_ | $SUDO tee /etc/puppetlabs/puppet/puppet.conf
[main]
    server = ${PUPPET_SERVER}
    ca_server = ${PUPPET_SERVER}

[agent]
    certificate = ${PUPPET_SERVER}
    certname = $(hostname --short)
    classfile = \$vardir/classes.txt
    daemonize = false
    environment = ${ENVIRONMENT}
    graph = true
    localconfig = \$vardir/localconfig
    number_of_facts_soft_limit = 8192
    onetime = true
    pluginsync = true
    show_diff = true
    splay = true
    usecacheonfailure = false
    report = true
    waitforcert = ${WAIT_FOR_CERT}
_EOF_


