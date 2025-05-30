# puppet-installers

Nothing fancy, just my bash-based Puppet (and OpenVox) installer scripts.  A few flags, including turning database/PuppetDB features on and off, autosigning, waitforcert, etc.

Vagrantfile included for bringing up a server and client instance to test things out, puppet-server and puppet-client.

Singularity container bits are there but not tested to the point I'd use it for anything other than making it better.  The Vagrantfile stanza for singularity will bring up a VM to build the container and dump the resulting simg to /var/tmp on the host system.  Not doing the container build directly on the host system because if you already have Puppet it will cause resource collisions.  PostgreSQL / PuppetDB disabled in the container as Postgres wants some fiddly bits with paths when external mounting that I've done but are just too janky looking for me to trust.

External Node Classifier not included but link shown.

This will have been all been done by someone else in less lines of code and with more extensive README documentation.

Eventually including funny readme documentation that makes me look more like a professional.

