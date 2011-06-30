# bfire
A powerful DSL to launch experiments on BonFIRE.

What this does for you:

* Nice DSL to declare the resources you want;
* Groups compute resources into... groups;
* Supports dependencies between groups, and builds the dependency graph to launch groups in the right order;
* Provision software on compute resources using [Puppet](http://www.puppetlabs.com/);
* Provides hooks after each deployment step so that you can launch your own commands;
* Abstracts SSH connections, including connections going through gateways;
* Registers metrics into Zabbix;
* Scale up or scale down groups based on any condition you want, including metric values.

This is very much a work in progress, and a proof of concept. 
The code is definitely not something you want to look at.

## Usage

    $ bfire my-experiment.rb

Or, if you are developing in the project's directory:

    $ git clone git://github.com/crohr/bfire.git
    $ cd bfire/
    $ ruby -I lib/ bin/bfire my-experiment.rb

Content of `my-experiment.rb`:

    set :name, "Simple Experiment using bfire"
    set :walltime, 3600
    set :gateway, "ssh.bonfire.grid5000.fr"
    set :user, ENV['USER']
    set :logging, INFO

    set :squeeze, "BonFIRE Debian Squeeze 2G v1"
    set :zabbix, "BonFIRE Zabbix Aggregator v2"
    set :wan, "BonFIRE WAN"

    group :monitor do
      at "uk-epcc"
      instance_type "small"
      deploy conf[:zabbix]
      connect_to conf[:wan]
    end

    group :servers do
      at "fr-inria"
      instance_type "small"
      deploy conf[:squeeze]
      connect_to conf[:wan]

      # This is not a runtime dependency, it starts right after the resources in
      # the monitor group have been _created_ (they're not necessarily _running_).
      depends_on :monitor do |group|
        {:aggregator_ip => group.take(:first)['nic'][0]['ip']}
      end
    end

    group :clients do
      at "fr-inria"
      at "de-hlrs"
      instance_type "small"
      deploy conf[:squeeze]
      connect_to conf[:wan]

      depends_on :monitor do |group|
        {:aggregator_ip => group.take(:first)['nic'][0]['ip']}
      end
      depends_on :servers do |group|
        {:server_ips => group.map{|vm| vm['nic'][0]['ip']}}
      end

      on :launched do
        puts "Yeah, our resources have been launched!"
      end

      # The ready event is generated once the group resources are launched AND
      # ssh accessible.
      on :ready do |group|
        group.each{|vm|
          puts "#{group.banner}#{vm['name']} - #{vm['nic'][0]['ip']}"
        }
      end
    end

See the `examples` directory for up to date examples.

## Authors
* Cyril Rohr <cyril.rohr@inria.fr>
