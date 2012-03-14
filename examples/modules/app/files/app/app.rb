require 'sinatra'

def registered?
  cmd = '. /etc/default/bonfire && unset http_proxy && curl -vf http://$BALANCER_IP:8000/hosts -X POST -d "ip=$WAN_IP"'
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

get '/stress' do
  duration = (params[:duration] || 5).to_i
  system "stress --cpu 2 --io 4 --vm 2 --vm-bytes 512M --timeout #{duration}s"
  "Stressed for #{duration}s"
end

get '/delay' do
  delay = (params[:delay] || 0).to_f
  sleep delay
  "Slept for #{delay}s."
end
