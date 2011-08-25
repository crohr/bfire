# Define global properties
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

# Monitoring
group :eye, :tag => "BonFIRE-monitor" do
  at "fr-inria"
  instance_type "small"
  deploy conf[:zabbix]
  connect_to conf[:wan]
end

# HTTP Routing
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
  register 'connection_waiting_time',
    :command => "/usr/bin/tail -n 1 /var/log/haproxy.log | cut -d ' ' -f 10 | cut -d '/' -f 2",
    :type => :numeric
end

# App servers
group :app do
  at "fr-inria"
  at "de-hlrs"
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
    :initial => 2,
    :up => lambda {|engine|
      values = engine.metric("connection_waiting_time",
        :hosts => engine.group(:web).take(:first),
        :type => :numeric
      ).values[0..3]
      puts "Metric values: #{values.inspect}, avg=#{values.avg.inspect}"
      values.avg >= 600
    },
    :down => lambda {|engine|
      engine.metric("connection_waiting_time",
        :hosts => engine.group(:web).take(:first),
        :type => :numeric
      ).values[0..5].avg < 200
    },
    :period => 90,
    :placement => :round_robin
  }
end

# All groups are "ready", launch an HTTP benchmarking tool against web's first
# resource on public interface:
on :ready do
  sleep 20
  cmd = "ab -r -c 8 -n 10000 http://#{group(:web).first['nic'].find{|n| n['ip'] =~ /^131/}['ip']}/delay?delay=0.3"
  system cmd
end

# Define your networks
network :public do |name, location|
  case location['name']
  when "fr-inria"
    location.networks.find{|network| network['name'] =~ /Public Network/i}
  end
end
