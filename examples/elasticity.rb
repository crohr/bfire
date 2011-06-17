# $ bfire elasticity.rb
#
set :name, "BonFIRE elasticity experiment"
set :description, "Whatever" # a UUID will be appended by the engine, so that
# we can later find it again based on that UUID (for instance if we want to
# rerun provisioning). --provision, --ignore-provisionning-errors, --no-cancel
set :key, "~/.ssh/id_rsa"
set :authorized_keys, "~/.ssh/authorized_keys"
set :walltime, 3600
set :gateway, "ssh.bonfire.grid5000.fr"
set :user, ENV['USER']
set :logging, DEBUG

set :squeeze, "BonFIRE Debian Squeeze 2G v1"
set :zabbix, "BonFIRE Zabbix Aggregator v2"
set :wan, "BonFIRE WAN"

# Define your networks
network :public do |name, location|
  case location['name']
  when "fr-inria"
    location.networks.find{|network| network['name'] =~ /Public Network/i}
  else
    nil
  end
end
network :internal do |name, location|
  location.networks.find{|n| n['name'] == name.to_s} ||
  experiment.networks.submit(
    :name => name.to_s, :location => location,
    :size => "C", :public => "NO", :address => "192.168.0.1"
  )
end

# Routing
group :web do
  at "fr-inria"
  instance_type 'small'
  deploy conf[:squeeze]
  # Two interfaces for the publicly facing server
  connect_to conf[:wan]
  connect_to :public

  provider :puppet,
    :classes => ['common', 'web'],
    :modules => "./modules"

  depends_on :eye do |g|
    {:aggregator_ip => g.take(:first)['nic'][0]['ip']}
  end

  # Register custom metrics
  register 'active_requests',
    :command => "/usr/bin/tail -n 1 /var/log/haproxy.log | cut -d ' ' -f 16 | cut -d '/' -f 1"

  on :ready do |g|
    g.each{|vm|
      puts "#{vm['name']} - #{vm['nic'][0]['ip']}"
    }
  end
  
end

# Monitoring
group :eye do
  at "fr-inria"
  instance_type "small"
  deploy conf[:zabbix]
  connect_to conf[:wan]
end

# App
group :app do
  at "fr-inria"
  # at "de-hlrs" do
  #   # connect_to :internal
  # end
  instance_type "small"
  connect_to conf[:wan]
  deploy conf[:squeeze]
  provider :puppet,
    :classes => ['common', 'app'],
    :modules => "./modules"
  
  depends_on :eye do |g|
    {:aggregator_ip => g.take(:first)['nic'][0]['ip']}
  end
  
  depends_on :web do |g|
    {:router_ip => g.take(:first)['nic'][0]['ip']}
  end
  
  # # Scaling
  # scale 2..10, {
  #   :initial => 3,
  #   :up => lambda { |metrics|
  #     metrics("req/s", :hosts => group(:web)).
  #     metrics["req/s"].values[0..15].avg >= 0.9
  #   },
  #   :down => lambda { |metrics|
  #     metrics["req/s"].values[0..5].avg <= 0.5
  #   },
  #   :period => 2.min,
  #   :placement => :round_robin
  # }
  
  # on :scaled_up do
  #   ip = group(:eye).take(:first)['nic'][0]['ip']
  #   session.put "http://#{ip}:8000/config", {
  #     :hosts => group(:app).map{|vm| vm['nic'][0]['ip']}.join(",")
  #   }
  # end
end

# All groups are "ready", launch an HTTP benchmarking tool against web's first
# resource on public interface:
on :ready do
  system "ab -c 50 -n 10000 http://#{group(:web).first['nic'][1]['ip']}/delay?delay=1.5"
end

# group :app do
#   at "de-hlrs"
#   instance_type "small"
#   deploy conf[:squeeze]
#   connect_to conf[:wan]
#   depends_on :eye do |g|
#     {:server_ip => g.take(:first)['nic'][0]['ip']}
#   end
#   on :ready do
#     group(:app).each do |vm|
#       ssh(vm['nic'][0]['ip'], 'root') {|s| puts s.exec!("apt-get install curl -y")}
#     end
#   end
# end

# group :app
#   # Location of resources
#   at "fr-inria", "uk-epcc"
#   at "de-hlrs" do
#     deploy('Squeeze 2G')
#   end
#   distribution :round_robin
#
#   # Common properties
#   deploy 'Squeeze'
#   instance_type :small
#
#   connect_to :wan, :device => :eth0
#   # connect_to :internal, :device => :eth1
#
#   provider :puppet, :classes => ['apache2']
#
#   register 'req/s', :period => 2.min, :command => "/usr/bin/wc -l /var/log/apache2/access.log"
#
#   # Scaling
#   scale 2..10, {
#     :initial => 3,
#     :up => lambda { |metrics|
#       metrics["req/s"].values[0..15].avg >= 0.9
#     },
#     :down => lambda { |metrics|
#       metrics["req/s"].values[0..5].avg <= 0.5
#     },
#     :period => 2.min
#   }
#
#   group(:web).on(:ready) do
#
#   end
#
#   # Does an SSH ping to check connection, before saying it is "ready"
#   on :ready do
#
#   end
# end

#
# # Experiment hooks / events
# on :stopped do
#   group(:eye).each do |vm|
#     vm.save_as("monitoring-data-#{vm['id']}")
#   end
# end


# Without location specified, chooses the first location which has the
# requested image.
