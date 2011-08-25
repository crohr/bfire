# $ bfire simple.rb

set :name, "Simple Experiment using bfire"
set :walltime, 3600
set :gateway, "ssh.bonfire.grid5000.fr"
set :user, ENV['USER']
set :logging, INFO

set :squeeze, "BonFIRE Debian Squeeze v4"
set :zabbix, "BonFIRE Zabbix Aggregator v4"
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
