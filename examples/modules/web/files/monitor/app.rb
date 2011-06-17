require 'sinatra'
require 'erb'
require 'set'

# Warning: that thing will need to run as root!

configure do
  set :hosts, Set.new
end

HAPROXY_CONFIG_FILE = "/etc/haproxy/haproxy.cfg"

helpers do
  def haproxy_config
    template = ERB.new(File.read(File.dirname(__FILE__)+'/haproxy.cfg.erb'))
    content = template.result(binding)
    File.open(HAPROXY_CONFIG_FILE, 'w+') do |f|
      f << content
    end
    true
  end
  
  def haproxy_restart
    system "/etc/init.d/haproxy restart"
  end
  
  def hosts
    settings.hosts
  end
end

get '/config' do
  File.read(HAPROXY_CONFIG_FILE)
end

post '/hosts' do
  ip = params[:ip]
  if ip
    settings.hosts.add(ip)
    haproxy_config && haproxy_restart
    "OK"
  else
    "KO - no IP provided"
  end
end

delete '/hosts/:ip' do |ip|
  settings.hosts.delete(ip)
  haproxy_config && haproxy_restart
  "OK"
end

get '/stats' do
  system "/usr/bin/tail -n 1 /var/log/haproxy.log"
end