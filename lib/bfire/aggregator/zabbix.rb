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
