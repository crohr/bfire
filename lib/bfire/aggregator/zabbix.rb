require 'json'

module Bfire
  module Aggregator
    class Zabbix
      def initialize(session, experiment, opts = {})
        @session = session
        @username = opts[:username] || "Admin"
        @password = opts[:password] || "zabbix"
        @experiment = experiment
        @token, @request_id = nil, 0
        @uri = @experiment.uri.to_s+"/zabbix"
        @max_attempts = 5
      end

      def request(method, params = {})
        begin
          authenticate if @token.nil? && method != "user.authenticate"
          @request_id += 1
          q = { "jsonrpc" => "2.0", "auth" => @token, "id" => @request_id,
                "method" => method, "params" => params }
          resource = @session.post(@uri,
            JSON.dump(q),
            :head => {
              'Content-Type' => 'application/json',
              'Accept' => 'application/json'
            }
          )
          # That fucking zabbix API returns "text/plain" as content-type...
          h = JSON.parse(resource.response.body)
          p [:response, h]
          if h['error']
            if h['error']['data'] == "Not authorized"
              @token = nil
              request(method, params)
            else
              raise StandardError, "Received error: #{h.inspect}" if h['error']
            end
          else
            h['result']
          end
        rescue Restfully::HTTP::Error => e
          # retry ad vitam eternam
          sleep 5
          retry
        end
      end

      def authenticate
        @token = request("user.authenticate", {"user" => @username, "password" => @password})
      end
    end
  end
end

__END__
zabbix = Zabbix.new("http://#{IP}/zabbix/api_jsonrpc.php", "Admin", "zabbix")
hostname = "web-fr-inria-440843f6-1271-4b8a-bdb4-3da25fc93bb2-754"

items = zabbix.request("item.get", {
  :filter => {
    "host" => hostname,
    "key_" => "active_requests"
  },
  "output" => "extend"
}).map{|i| i['itemid']}

puts "*** Items for host #{hostname}:"
p items

# Most recent last
puts "*** History for items 0..3:"
results = zabbix.request("history.get", {
  "itemids" => items[0..3],
  "output" => "extend",
  "time_from" => Time.now.to_i-600
})
results.map!{|r| r['clock'] = Time.at(r['clock'].to_i).to_s; r}
p results

__END__
$ ruby zabbix.rb

RestClient.post "http://131.254.204.190/zabbix/api_jsonrpc.php", "{\"auth\":null,\"method\":\"user.authenticate\",\"id\":1,\"params\":{\"password\":\"zabbix\",\"user\":\"Admin\"},\"jsonrpc\":\"2.0\"}", "Accept"=>"application/json", "Accept-Encoding"=>"gzip, deflate", "Content-Length"=>"111", "Content-Type"=>"application/json"
# => 200 OK | text/html 85 bytes
RestClient.post "http://131.254.204.190/zabbix/api_jsonrpc.php", "{\"auth\":\"186493726dcdde4b8e3aa41ae71b22e3\",\"method\":\"item.get\",\"id\":2,\"params\":{\"host\":\"server-experiment#442-473\"},\"jsonrpc\":\"2.0\"}", "Accept"=>"application/json", "Accept-Encoding"=>"gzip, deflate", "Content-Length"=>"132", "Content-Type"=>"application/json"
# => 200 OK | text/html 360 bytes

*** Items for host server-experiment#442-473:
["22470", "22471", "22472", "22473", "22474", "22475", "22476", "22477", "22478", "22479", "22480", "22481", "22482", "22483", "22484", "22485", "22486", "22487", "22488", "22489", "22490", "22491", "22492", "22493", "22494", "22495", "22496", "22497", "22498", "22499", "22500", "22501", "22502", "22503", "22504", "22505", "22506", "22507", "22508", "22509", "22510", "22511", "22512", "22513", "22514", "22515", "22516", "22517", "22518", "22519", "22520", "22521", "22522", "22523", "22524", "22525", "22526", "22527", "22528", "22529", "22530", "22531", "22532", "22533", "22534", "22535", "22536", "22537", "22538", "22539", "22540", "22541", "22542", "22543", "22544", "22545", "22546", "22547", "22548", "22549", "22550", "22551", "22552", "22553", "22554", "22555", "22556", "22557", "22558", "22559", "22560", "22561", "22562", "22563", "22564", "22565", "22566", "22567", "22568", "22569", "22570", "22571"]

*** History for items 0..3:
RestClient.post "http://131.254.204.190/zabbix/api_jsonrpc.php", "{\"auth\":\"186493726dcdde4b8e3aa41ae71b22e3\",\"method\":\"history.get\",\"id\":3,\"params\":{\"itemids\":[\"22470\",\"22471\",\"22472\",\"22473\"]},\"jsonrpc\":\"2.0\"}", "Accept"=>"application/json", "Accept-Encoding"=>"gzip, deflate", "Content-Length"=>"144", "Content-Type"=>"application/json"
# => 200 OK | text/html 126 bytes
Desktop/zabbix.rb:21:in `request': Received error: {"id"=>3, "jsonrpc"=>"2.0", "error"=>{"data"=>"Resource (history) does not exist", "code"=>-32602, "message"=>"Invalid params."}} (StandardError)
	from Desktop/zabbix.rb:41