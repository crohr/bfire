# $ bfire elasticity.rb

# Define global properties
set :name, "snooze-experiment"
set :key, "~/.ssh/demo"
set :authorized_keys, "~/.ssh/authorized_keys"
set :walltime, 7200
# set :gateway, "snooze4"
set :user, "root"
# password for VMs
set :password, "snoozeroot"
set :logging, INFO

set :default, "snooze-image"
set :wan, "private-network"
set :http_proxy, ENV['HTTP_PROXY'] || "http://proxy.rennes.grid5000.fr:3128"
set :balancer_ip, (ENV['BALANCER_IP'] || fail("Need BALANCER_IP env variable"))

# App servers
group :backend do
  at "snooze"
  instance_type "lite"
  connect_to conf[:wan]
  deploy conf[:default]
  provider :puppet,
    :classes => ['common', 'app'],
    :modules => "./modules"

  context :http_proxy => conf[:http_proxy], :balancer_ip => conf[:balancer_ip]

  # Scaling
  scale 1..200, {
    :initial => 2,
    :count => 3,
    :up => lambda {|engine|
      fire = false
      engine.ssh(conf[:balancer_ip], 'root') do |ssh|
        result = ssh.exec!("/usr/bin/tail -n 10 /var/log/haproxy.log | cut -d ' ' -f 10 | cut -d '/' -f 2")
        p [:result, result]
        fire = unless result.nil?
          values = result.split("\n").reverse.map{|v| v.to_f}
          puts "Metric values: #{values.inspect}, avg=#{values[0..3].avg.inspect}"
          values[0..3].avg >= 600
        else
          false
        end
      end
      fire
    },
    :period => 15,
    :placement => :round_robin
  }
end

# All groups are "ready", launch an HTTP benchmarking tool against balancer IP:
on :ready do
  sleep 20
  puts "***********"
  cmd = "ab -r -c 60 -n 1000000 -g /tmp/ab-`date +%s`.dat http://#{conf[:balancer_ip]}/stress?duration=3"
  puts "***********"
  puts cmd
  # system cmd
end

