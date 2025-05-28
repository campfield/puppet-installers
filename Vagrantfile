#
#
# A Vagrantfile for bringing up a Puppet server and client/agent.
#
#

require 'digest/md5'


#
# Classifier utiled by Campfield:
#  https://github.com/southalc/enc.git
#
CLASSIFIER = 'enc-southalc/bin/enc.rb'
# CLASSIFIER = 'enc.sh'


VAGRANTFILE_API_VERSION = '2'

#
# Default VirtualBox Prefix
#
NETWORK_PREFIX = '192.168.56'

#
# Used for giving VM names uniqueness based on Vagrantfile path.
#
REALPATH_DIGEST = Digest::MD5.hexdigest(File.realpath(File.dirname(__FILE__)))[0..3]

#
# Local development can switch guest properties between laptop and 1U server.
#
HYPERVISOR_HOSTNAME = Socket.gethostname

PUPPET_SOURCE = ENV['PUPPET_SOURCE'] || 'files/puppet'
#PUPPET_SOURCE = 'files/puppet'

#
# Upgrade the guest OS on instantiation
#
OS_UPGRADE = false

PUPPET_SERVER = 'puppet'

PUPPET_ENVIRONMENT = 'production'

#
# Puppet Inc. vs OpenVOX
#
PROVIDER = 'puppetlabs'
PROVIDER = 'openvox'

VM_BOX = 'generic/ubuntu2204'

#
# -a autosign
# -c classifier
# -d enable database
# -e puppet environment
# -p provider [openvox|puppetserver]
# -s puppet server name
# -w wait for cert
#
PUPPET_OPTIONS = "-d -c #{CLASSIFIER} -e #{PUPPET_ENVIRONMENT} -w -a -p #{PROVIDER} -s #{PUPPET_SERVER}"

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
  # unique mac addresses
  config.vm.base_mac = nil

  #
  # Use this directory for inlining the install scripts.
  #
  config.vm.synced_folder '.', '/mnt/puppet'


  #
  # Vagrant plugin handles guest-to-guest-to-host DNS exhcnage instead of DNSmasq as
  #  previously used.
  #
  if Vagrant.has_plugin?('vagrant-hostmanager')
    config.vm.provision :hostmanager
    config.hostmanager.enabled = true
    config.hostmanager.ignore_private_ip = false
    config.hostmanager.include_offline = false
    config.hostmanager.manage_guest = true
    config.hostmanager.manage_host = false
  end

  #
  # If VirtualBox then configure automatic upgrading of virtual extensions packages.
  #
  if Vagrant.has_plugin?('vagrant-vbguest')
    config.vbguest.auto_update = false
    config.vbguest.no_remote = true
  end

  config.vm.box = VM_BOX

  #
  # Local 1U server with cached repos.
  #
  if HYPERVISOR_HOSTNAME == 'napier' and File.exist?('files/local/repos-napier.sh')
    config.vm.provision 'shell', path: 'files/local/repos-napier.sh'
  end

  #
  # Upgrade OSes on instantiation
  #
  if OS_UPGRADE
    config.vm.provision 'shell', inline: 'sudo apt-get -y update;'
    config.vm.provision 'shell', inline: 'sudo apt-get -y dist-upgrade'
  end


  config.vm.define 'puppet-server', primary: true, autostart: true do |server|
    server.vm.hostname = 'puppet'

    server.hostmanager.aliases = 'puppet'

    #
    # Puppet server network port forwarding.  Probably should make this a fqdn_rand() type of thing spread to the
    #  clients so I can eventually make multiple Puppets on the same host.
    #
    server.vm.network 'forwarded_port', guest: 8140, host: 8140, id: "puppet-#{REALPATH_DIGEST}", auto_correct: false

    # Don't use the 10.0.2.3 IPs given by VirtualBox and Vagrant.  Use a VirtualBox intnet device and IP.
    server.vm.network :private_network, ip: "#{NETWORK_PREFIX}.151", virtualbox__intnet: true

    # In theory these should all be there.  In theory.
    if File.exist?(PUPPET_SOURCE) and File.directory?(File.realpath(PUPPET_SOURCE))
      server.vm.synced_folder PUPPET_SOURCE, "/etc/puppetlabs/code/environments/#{PUPPET_ENVIRONMENT}"
      server.vm.synced_folder "#{PUPPET_SOURCE}/classifiers", '/etc/puppetlabs/code/classifiers'
      server.vm.synced_folder "#{PUPPET_SOURCE}/hiera", '/etc/puppetlabs/code/hiera'
    end

    server.vm.provider 'virtualbox' do |vb|
      vb.linked_clone = true
      vb.name = "server-#{REALPATH_DIGEST}"

      if HYPERVISOR_HOSTNAME == 'napier'
        vb.memory = 16384
        vb.cpus = 8
      else
        vb.memory = 8192
        vb.cpus = 4
      end
    end

    #
    # Look at me inlining scripts without doing proper exist checks.
    #
    server.vm.provision 'shell', inline: "sudo /mnt/puppet/files/installers/puppet/puppet-server.sh #{PUPPET_OPTIONS}"
    server.vm.provision 'shell', inline: "sudo /mnt/puppet/files/installers/puppet/scripts-default.sh #{PUPPET_OPTIONS}"
    server.vm.provision 'shell', inline: "sudo /mnt/puppet/files/installers/puppet/scripts-server.sh #{PUPPET_OPTIONS}"
  end


  #
  # slient verse, nearly same as the first.
  #
  config.vm.define 'client', primary: false, autostart: false do |agent|
    agent.vm.hostname = 'client'
    agent.hostmanager.aliases = 'client'

    agent.vm.network :private_network, ip: "#{NETWORK_PREFIX}.152", virtualbox__intnet: true

    agent.vm.provider 'virtualbox' do |vb|
      vb.linked_clone = true
      vb.name = "client-#{REALPATH_DIGEST}"

      if HYPERVISOR_HOSTNAME == 'napier'
        vb.memory = 8096
        vb.cpus = 4
      else
        vb.memory = 2048
        vb.cpus = 2
      end
    end

    agent.vm.provision 'shell', inline: "sudo /mnt/puppet/files/installers/puppet/puppet-agent.sh #{PUPPET_OPTIONS}"
    agent.vm.provision 'shell', inline: "sudo /mnt/puppet/files/installers/puppet/scripts-default.sh #{PUPPET_OPTIONS}"

  end

# https://github.com/apptainer/apptainer/releases/download/v1.4.1/apptainer_1.4.1_amd64.deb"

  #
  # slient verse, nearly same as the first.
  #
  config.vm.define 'singularity', primary: false, autostart: false do |singularity|
    singularity.vm.hostname = 'singularity'
    singularity.hostmanager.aliases = 'singularity'

    singularity.vm.synced_folder "/var/tmp", '/mnt/singularity'

    singularity.vm.provider 'virtualbox' do |vb|
      vb.linked_clone = true
      vb.name = "singularity-#{REALPATH_DIGEST}"

      if HYPERVISOR_HOSTNAME == 'napier'
        vb.memory = 8096
        vb.cpus = 4
      else
        vb.memory = 2048
        vb.cpus = 2
      end
    end

    singularity.vm.provision 'shell', inline: "sudo /mnt/puppet/files/installers/singularity/apptainer-install-ppa.sh"
#    singularity.vm.provision 'shell', inline: "sudo /mnt/puppet/files/installers/singularity/puppet-server-simg.sh #{PUPPET_OPTIONS}"


  end

end

