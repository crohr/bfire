require 'sinatra'

Thread.new{
  # Register with the server on launch
  # Not efficient but works
  cmd = '. /etc/default/bonfire && curl -f http://$ROUTER_IP:8000/hosts -X POST -d "ip=$WAN_IP"'
  while system(cmd) && $?.exitstatus != 0
    puts "ROUTER not ready yet (status=#{$?.exitstatus}, cmd=#{cmd.inspect})."
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
