require 'sinatra'

# Register with the server on launch
# Not efficient but works
cmd = 'source /etc/default/bonfire && curl http://$ROUTER_IP:8000/hosts -X POST -d "ip=$WAN_IP"'
while system(cmd) != "OK"
  puts "ROUTER not ready yet (cmd=#{cmd.inspect})."
  sleep 3
end

get '/delay' do
  delay = (params[:delay] || 0).to_f
  sleep delay
  "Slept for #{delay}s."
end
