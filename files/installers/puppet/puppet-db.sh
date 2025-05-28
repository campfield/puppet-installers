#!/bin/bash


$SUDO apt-get -y install \
  postgresql \
  postgresql-contrib \
  uuid

#
# Used for setting randomized passwords
#
export UUID=$(uuid)
  #
  # If you are upgrading this unit's version of postgresql - probably just want to reinstall.
  #
export POSTGRESQL_VERSION=$($SUDO ls /var/lib/postgresql | grep -v data | tail -1)

if [[ ! -d /var/lib/postgresql/$POSTGRESQL_VERSION/data ]]; then
  $SUDO service postgresql restart
  $SUDO su - postgres -c "/usr/lib/postgresql/$POSTGRESQL_VERSION/bin/initdb -D /var/lib/postgresql/$POSTGRESQL_VERSION/data"
  $SUDO su - postgres -c "echo -e '${UUID}\n${UUID}' | createuser -DRSP puppetdb;"
  $SUDO su - postgres -c 'createdb -E UTF8 -O puppetdb puppetdb;'
  $SUDO su - postgres -c "psql puppetdb -c 'create extension pg_trgm';"
  echo "${UUID}" | $SUDO tee -a /etc/postgresql/users-puppetdb-password
fi

$SUDO service postgresql restart

$SUDO apt-get -y install \
  hiera-eyaml \
  ${PROVIDER}db \
  ${PROVIDER}db-termini


cat << _EOF_ >> /etc/puppetlabs/puppet/puppet.conf
    reports = puppetdb
    storeconfigs = true
    storeconfigs_backend = puppetdb
_EOF_




$SUDO cat << _EOF_ > /etc/puppetlabs/puppet/routes.yaml
---

master:
  facts:
    cache: yaml
    terminus: puppetdb

_EOF_
$SUDO chmod 644 /etc/puppetlabs/puppet/routes.yaml
$SUDO chown puppet:puppet /etc/puppetlabs/puppet/routes.yaml



#
#
#
#
#

$SUDO crudini --set /etc/puppetlabs/puppetdb/conf.d/database.ini database password ${UUID}
$SUDO crudini --set /etc/puppetlabs/puppetdb/conf.d/database.ini database subname '//localhost:5432/puppetdb'
$SUDO crudini --set /etc/puppetlabs/puppetdb/conf.d/database.ini database username puppetdb

$SUDO crudini --set /etc/puppetlabs/puppet/puppetdb.conf main server_url_timeout 300
$SUDO crudini --set /etc/puppetlabs/puppet/puppetdb.conf main server_urls "https://${PUPPET_SERVER}:8081"

$SUDO chmod 644 /etc/puppetlabs/puppet/puppetdb.conf
$SUDO chown puppet:puppetdb /etc/puppetlabs/puppet/puppetdb.conf


$SUDO cat << _EOF_ > /etc/puppetlabs/puppetdb/conf.d/jetty.ini

[jetty]

access-log-config = /etc/puppetlabs/puppetdb/request-logging.xml
client-auth = want
host = 0.0.0.0
port = 8080
ssl-ca-cert = /etc/puppetlabs/puppetdb/ssl/ca.pem
ssl-cert = /etc/puppetlabs/puppetdb/ssl/public.pem
ssl-host = 0.0.0.0
ssl-key = /etc/puppetlabs/puppetdb/ssl/private.pem
ssl-port = 8081

_EOF_
$SUDO chmod 644 /etc/puppetlabs/puppetdb/conf.d/jetty.ini
$SUDO chown -R puppet:puppetdb /etc/puppetlabs/puppetdb/



#
# PuppetDB SSL Setup
#  Watch out - we are blindly removing the old SSL items.
#

$SUDO service puppetdb stop
$SUDO rm -rf /etc/puppetlabs/puppetdb/ssl
$SUDO /opt/puppetlabs/server/apps/puppetdb/cli/apps/ssl-setup -f

for SERVICE_NAME in postgresql puppetdb; do
  $SUDO systemctl enable $SERVICE_NAME
  $SUDO systemctl restart $SERVICE_NAME
done


