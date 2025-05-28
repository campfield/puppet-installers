#!/bin/bash

echo "Executiong [$0]"

export OPENVOX_VERSION='openvox8'
export PUPPET_VERSION='puppet8'

export PUPPET_SERVER=$(hostname --short)

export PATH="/opt/puppetlabs/bin:$PATH"
export ENVIRONMENT='fairchilde'
export DEBIAN_FRONTEND='noninteractive'

export BIN_DIRECTORY='/opt/puppetlabs/bin'
export LOG_DIRECTORY='/var/log/puppetlabs'

export DB_ENABLE=false
export WAIT_FOR_CERT=false
export CERT_AUTOSIGN=false


if [[ -z $PROVIDER ]]; then
  export PROVIDER='openvox'
fi

export RELEASE_DEB_TARGET='/dev/shm/provider-release.deb'


#
# systemctl is not used as it does not work properly in containered
#  environments (e.g., singularity) but the service command still works
#  as expected.
#
if [[ -f /.dockerenv ]]; then
  export VIRT_PROVIDER='docker'
  export CONTAINER=true
  export SUDO=
elif [[ -e /singularity ]]; then
  export VIRT_PROVIDER='singularity'
  export CONTAINER=true
  export SUDO=
elif [[ ! -z "$(lsmod | grep vboxguest)" ]]; then
  export VIRT_PROVIDER='virtualbox'
  export CONTAINER=false
  export SUDO='sudo -E'
else
  export VIRT_PROVIDER='none'
  export CONTAINER=false
  export SUDO='sudo -E'
fi

if [[ $CONTAINER == 'false' ]] && [[ ${EUID} -ne 0 ]]; then
  echo "[ERROR] script [$0] must be run as user [root] not [$USER], exiting."
  exit 1
fi

#cat << _EOF_ > /etc/apt/apt.conf.d/98keepold.conf
#Dpkg::Options {
#   '--force-confdef';
#   '--force-confold';
#}
#_EOF_

cat << _EOF_ > /etc/apt/apt.conf.d/98force-confdef-evil.conf
Dpkg::Options {
  "--force-confdef";
}
_EOF_

$SUDO apt-get update

$SUDO apt-get -y install \
  aptitude \
  lsb-core \
  wget

#
# LSB Core provides extra results pulled by the facter program.
#
export UBUNTU_RELEASE_CODENAME=$(lsb_release -c -s)

#
# Provides distrib release and codename
#
source /etc/lsb-release
source /etc/os-release

#
# Linux Mint, bless its heart, uses its own codenames that need to be
#  translated.
#
case $UBUNTU_RELEASE_CODENAME in
  'wilma')
    export UBUNTU_RELEASE_CODENAME='noble'
    ;;
  'virginia' | 'victoria' | 'vera' | 'vanessa')
    export UBUNTU_RELEASE_CODENAME='jammy'
    ;;
  'una' | 'ulyssa' | 'ulyana')
    export UBUNTU_RELEASE_CODENAME='focal'
    ;;
esac

#
# TODO: Add non-lts release numbers
#

export RELEASE_DEB_SOURCE="https://apt.voxpupuli.org/${OPENVOX_VERSION}-release-ubuntu${DISTRIB_RELEASE}.deb"

while getopts "s:dwae:p:c:" options; do
  case "${options}" in
    e)
      export ENVIRONMENT=${OPTARG}
      ;;
    s)
      export PUPPET_SERVER=${OPTARG}
      ;;
    c)
      export CLASSIFIER=${OPTARG}
      ;;
    d)
      export DB_ENABLE=true
      ;;
    w)
      export WAIT_FOR_CERT=true
      ;;
    p)
      export PROVIDER=${OPTARG}
      if [[ $PROVIDER != 'puppetlabs' ]] && [[ $PROVIDER != 'openvox' ]]; then
        echo "Provider [$PROVIDER] must be one of [puppetlabs|openvox], received [$PROVIDER], exiting."
        exit 1
      elif [[ $PROVIDER == 'puppetlabs' ]]; then
        export RELEASE_DEB_SOURCE="https://apt.puppet.com/${PUPPET_VERSION}-release-${UBUNTU_RELEASE_CODENAME}.deb"
        # dumb switchback to handle variable naming of files and configs.
        PROVIDER='puppet'
      fi
      ;;
    a)
      #
      # Validate if security is important to this project.  If
      #  value is set to [true] then it is not.  I always set it
      #  to autosign false because I'm a proper sysadmin who also
      #  runs his toaster in FIPS mode.
      #
      export CERT_AUTOSIGN=true
      ;;
    *)
      ;;
    esac
done
shift $((OPTIND-1))

#
#
# containers generally do not have locales installed which can cause multiple services
#  to not perform correctly.  Mostly seen in Singularity.
#
#
if [[ $CONTAINER == 'true' ]]; then
  $SUDO apt-get -y install locales locales-all
  $SUDO localedef --no-archive -i en_US -f UTF-8 en_US.UTF-8;
else

for SERVICE_NAME in apparmor; do
  $SUDO update-rc.d $SERVICE_NAME disable
  $SUDO service $SERVICE_NAME stop
done

if [[ $(which pro 2>/dev/null) ]]; then
  $SUDO pro config set apt_news=false
fi

#
# Disabling IPv6.
#
cat <<- _EOF_ > /etc/sysctl.d/ipv6-disable.conf
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
_EOF_

#
# Default notifys are miserable.
#
cat <<- _EOF_ > /etc/sysctl.d/puppetserver.conf
fs.inotify.max_queued_events=1048576
fs.inotify.max_user_instances=1048576
fs.inotify.max_user_watches=1048576
_EOF_

#
# Where we are going, we don't need limits.
#
cat <<- _EOF_ > /etc/security/limits.d/puppetserver.conf
* soft nofile unlimited
* hard nofile unlimited
* soft nproc unlimited
* hard nproc unlimited
* hard core 0
* soft core 0
_EOF_

sysctl -p

fi

if [[ -e $RELEASE_DEB_TARGET ]] && [[ ! -s $RELEASE_DEB_TARGET ]]; then
  $SUDO /bin/rm $RELEASE_DEB_TARGET
fi

if [[ ! -e $RELEASE_DEB_TARGET ]]; then
  $SUDO wget -O $RELEASE_DEB_TARGET $RELEASE_DEB_SOURCE
fi

$SUDO dpkg -i $RELEASE_DEB_TARGET
$SUDO apt-get update
