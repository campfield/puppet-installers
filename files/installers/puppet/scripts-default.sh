#!/bin/bash

export SOURCE_DIRECTORY=$(dirname $(realpath $0))

source ${SOURCE_DIRECTORY}/boilerplate.sh

#
# rp: Run puppet - quicky one-time Puppet agent run.
#
cat << _EOF_ | $SUDO tee /usr/local/sbin/rp
#!/bin/bash

#
#  Allow us to fix noop the files.
#
declare NOOP_FILE='/etc/puppetlabs/puppet/agent-noop.txt'

if [[ -e \${NOOP_FILE} ]]; then
  echo "Program [puppet] blocked by presence of [\${NOOP_FILE}], exiting."
  exit 1
elif [[ ! -x ${BIN_DIRECTORY}/puppet ]]; then
  echo "Program [puppet] missing/non-executable, exiting."
  exit 1
fi

if [[ -d /etc/puppetlabs/code/environments ]]; then
  $SUDO chmod -R 755 /etc/puppetlabs/code/environments
fi


${BIN_DIRECTORY}/puppet agent --enable;

if [[ ! -d "${LOG_DIRECTORY}" ]]; then
  mkdir --mode=0750 "${LOG_DIRECTORY}"
  chown -R puppet:puppet "${LOG_DIRECTORY}"
fi

${BIN_DIRECTORY}/puppet agent --test

${BIN_DIRECTORY}/puppet agent --disable;

_EOF_
$SUDO chmod 4755 /usr/local/sbin/rp
$SUDO chown root:root /usr/local/sbin/rp


