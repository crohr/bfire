# $ bfire elasticity.rb
#

set :name, "BonFIRE elasticity experiment"
set :key, "~/.ssh/id_rsa"
set :authorized_keys, "~/.ssh/authorized_keys"
set :walltime, 3600
set :gateway, "ssh.bonfire.grid5000.fr"
set :user, ENV['USER']
set :logging, INFO

set :squeeze, "BonFIRE Debian Squeeze 2G v1"
set :zabbix, "BonFIRE Zabbix Aggregator v2"
set :wan, "BonFIRE WAN"

# Define your networks
network :internal do |name, location|
  location.networks.find{|n| n['name'] == name.to_s} ||
  experiment.networks.submit(
    :name => name.to_s, :location => location,
    :size => "C", :public => "NO", :address => "192.168.0.1"
  )
end



group :web do
  at "fr-inria"
  at "de-hlrs" do
    # connect_to :internal
  end
  instance_type 'small'
  deploy conf[:squeeze]
  connect_to conf[:wan]
  provider :puppet,
    :classes => ['haproxy'],
    :modules => "./modules"
  depends_on :eye do |g|
    {:aggregator_ip => g.take(:first)['nic'][0]['ip']}
  end

  # Register custom metrics
  # register 'http_requests',
  #   :period => 120,
  #   :command => "/usr/bin/wc -l /var/log/apache2/access.log"
  
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
  on :ready do
    group(:web).each{|compute|
      puts "#{compute['name']} - #{compute['nic'][0]['ip']}"
    }
  end
end
#

# Without location specified, chooses the first location which has the
# requested image.
group :eye do
  at "de-hlrs"
  instance_type "small"
  deploy conf[:zabbix]
  connect_to conf[:wan]
end

group :app do
  at "de-hlrs"
  instance_type "small"
  deploy conf[:squeeze]
  connect_to conf[:wan]
  depends_on :eye do |g|
    {:server_ip => g.take(:first)['nic'][0]['ip']}
  end
  on :ready do
    group(:app).each do |vm|
      ssh(vm['nic'][0]['ip'], 'root') {|s| puts s.exec!("apt-get install curl -y")}
    end
  end
end

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

# # All groups are "ready"
# on :ready do
#   system "ab -c 50 -n 1000 http://#{group(:web).first['nic'][0]['ip']}/"
# end
#
# # Experiment hooks / events
# on :stopped do
#   group(:eye).each do |vm|
#     vm.save_as("monitoring-data-#{vm['id']}")
#   end
# end
