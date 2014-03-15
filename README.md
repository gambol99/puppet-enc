Puppet External Node Classifer
=========================

Puppet-enc is a external node classifier for puppet. The classification file itself is a standard yaml file

    --- 
    stats: 
      last_updated: "323232323"
    groups: 
      puppet::default: 
        puppet: 
      all: 
        base: 
        puppet: 
      default: 
        ntp: 
        base: 
    nodes: 
      perdb301-hsk.mydomain.com: 
        parameters: {}
        classes: 
          base::default: {}
          opennebula::vm: {}
          mol::contentdb:
        groups: 
          puppet::default: {}
      graphite301-hsk.mydomain.com: 
        parameters: {}
        classes: 
          base::default: {}
          mol::graphite: {}
          opennebula::vm: {}
        groups: 
          puppet::default: {}
          
All the nodes a enclosed in the nodes array. The classifier also supports notion of groups which are merged into the final classification; note: the merging supports bottom down priority, i.e. the attributes of the nodes override attributes from the inherited group.


bin/classify.rb
===============

The classifier comes classify.rb; example usage

    :puppet.conf

    [main]
      # The Puppet log directory.
      # The default value is '$vardir/log'.
      logdir = /var/log/puppet

      # Where Puppet PID files are kept.
      # The default value is '$vardir/run'.
      rundir = /var/run/puppet

      # Where SSL certificates are kept.
      # The default value is '$confdir/ssl'.
      ssldir = $vardir/ssl

      node_terminus  = exec
      external_nodes = /etc/puppet/bin/classify.rb -q -H

Command line;

    # classify.rb -H myhost.fqdn


