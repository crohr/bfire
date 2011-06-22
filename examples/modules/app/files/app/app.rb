require 'sinatra'

def registered?
  cmd = '. /etc/default/bonfire && curl -f http://$ROUTER_IP:8000/hosts -X POST -d "ip=$WAN_IP"'
  system(cmd)
  $?.exitstatus == 0
rescue Exception => e
  puts "Received #{e.class.name}: #{e.message}"
  false
end

Thread.new{
  # Register with the server on launch
  # Not efficient but works
  until registered? do
    puts "ROUTER not ready yet."
    sleep 3
  end
}


get '/' do
  "UP"
end

get '/delay' do
  delay = (params[:delay] || 0).to_f
  sleep delay
  "Slept for #{delay}s."
end
