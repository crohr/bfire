# $ bfire elasticity.rb
set :name, "BonFIRE elasticity experiment"
set :key, "~/.ssh/id_rsa"
set :authorized_keys, "~/.ssh/authorized_keys"
set :walltime, 7200
set :gateway, "ssh.bonfire.grid5000.fr"
set :user, ENV['USER']
set :logging, DEBUG

set :squeeze, "BonFIRE Debian Squeeze 2G v1"
set :zabbix, "BonFIRE Zabbix Aggregator v2"
set :wan, "BonFIRE WAN"

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
  
  # Scaling
  scale 1..10, {
    :initial => 1,
    :up => lambda {|engine|
      m = engine.metric(
        "active_requests", 
        :hosts => engine.group(:web).take(:first)
      )
      p [:m, m]
      m.values[0..15].avg > 5
    },
    :down => lambda {|engine|
      engine.metric(
        "active_requests", 
        :hosts => engine.group(:web).take(:first)
      ).values[0..15].avg < 5
    },
    :period => 60,
    :placement => :round_robin
  }
  
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
  cmd = "ab -c 5 -n 10000 http://#{group(:web).first['nic'].find{|n| n['ip'] =~ /^131/}['ip']}/delay?delay=0.2"
  puts "***********"
  puts cmd
  system cmd
end

# Define your networks
network :public do |name, location|
  case location['name']
  when "fr-inria"
    location.networks.find{|network| network['name'] =~ /Public Network/i}
  end
end

network :internal do |name, location|
  location.networks.find{|n| n['name'] == name.to_s} ||
  experiment.networks.submit(
    :name => name.to_s, :location => location,
    :size => "C", :public => "NO", :address => "192.168.0.1"
  )
end