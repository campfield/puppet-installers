#!/bin/bash

export SOURCE_DIRECTORY=$(dirname $(realpath $0))

source ${SOURCE_DIRECTORY}/boilerplate.sh

#
# Script that allows you to start, restart, and stop puppetserver.
#  Recall that we use 'service' instead of systemctl as the latter does
#  not behave well under containers.  There is probably an obvious solution
#  that I've not looked up
#
if [[ $DB_ENABLE == 'true' ]]; then
  PUPPET_START_LIST='postgresql puppetdb puppetserver'
  PUPPET_STOP_LIST='puppetserver puppetdb postgresql'
else
  PUPPET_START_LIST='puppetserver'
  PUPPET_STOP_LIST='puppetserver'
fi

#
# Handy control scripts for managing services.
#
cat << _EOF_ | $SUDO tee /usr/local/sbin/puppet-ctl
#!/bin/bash

if [[ -z \$1 ]]; then
  ACTION=restart
else
  ACTION=\$1
fi

SERVICE_STATE=('start' 'stop' 'restart')
if ! [[ \$(echo \${SERVICE_STATE[@]} | fgrep -w \${ACTION}) ]]; then
  echo "Invalid action to [puppetserver] [\${ACTION}].  Valid actions [start], [stop], and [restart]."
else
  echo "Performing [\${ACTION}] for [puppetserver] software stack."
fi

if [[ \${ACTION} == 'restart' ]]; then

  for SERVICE_NAME in ${PUPPET_STOP_LIST}; do
    echo "Stopping [\$SERVICE_NAME]."
    $SUDO service \${SERVICE_NAME} stop
    $SUDO update-rc.d \${SERVICE_NAME} disable
  done

  for SERVICE_NAME in ${PUPPET_START_LIST}; do
    echo "Starting [\$SERVICE_NAME]."
    $SUDO service \${SERVICE_NAME} start
    $SUDO update-rc.d \${SERVICE_NAME} enable
  done

elif [[ \${ACTION} == 'stop' ]]; then

  for SERVICE_NAME in ${PUPPET_STOP_LIST}; do
    echo "Stopping [\$SERVICE_NAME]."
    $SUDO service \${SERVICE_NAME} stop
    $SUDO update-rc.d \${SERVICE_NAME} disable
  done

elif [[ \${ACTION} == 'start' ]]; then
  for SERVICE_NAME in ${PUPPET_START_LIST}; do
    echo "Starting [\$SERVICE_NAME]."
    $SUDO service \${SERVICE_NAME} start
    $SUDO update-rc.d \${SERVICE_NAME} enable
  done
fi

_EOF_
$SUDO chmod 4755 /usr/local/sbin/puppet-ctl
$SUDO chown root:root /usr/local/sbin/puppet-ctl
$SUDO ln -s /usr/local/sbin/puppet-ctl /usr/local/sbin/p

#
# Sign all agent requests.
#
cat << _EOF_ | $SUDO tee /usr/local/sbin/puppet-sign-all
#!/bin/bash

declare SLEEP_TIME=4

declare CERTLIST=\$(${PUPPETLABS_BIN_DIRECTORY}/puppetserver ca list)

if [[ \${CERTLIST} == 'No certificates to list' ]]; then
  echo 'These are no pending certificates awaiting signing/approval.'
  exit
fi

echo 'These are the certificates awaiting signing/approval:'
echo
${PUPPETLABS_BIN_DIRECTORY}/puppetserver ca list
echo
echo "Signing certificates in [\${SLEEP_TIME}] seconds.  Enter CTRL-C to cancel."

sleep \${SLEEP_TIME}

${PUPPETLABS_BIN_DIRECTORY}/puppetserver ca sign --all

_EOF_
$SUDO chmod 4755 /usr/local/sbin/puppet-sign-all
$SUDO chown root:root /usr/local/sbin/puppet-sign-all
