require 'pry'
module AMQParty
  class Request < HTTParty::Request
    def perform(&block)
      validate
      setup_raw_request
      chunked_body = nil

      # binding.pry
      Rack::AMQP::Client.with_client(host: 'localhost') do |client|
        Timeout.timeout(10) do
          method_name = http_method.name.split(/::/).last.upcase
          body = HTTParty::HashConversions.to_params(options[:body]) || ""
          response = client.request(uri.to_s.sub('amqp://',''), {body: body, http_method: method_name, timeout: 5})
          # TODO convert repsonse into HTTPResponse and assign to last_response
          klass = Net::HTTPResponse.send(:response_class,response.response_code.to_s)
          http_response = klass.new("1.1", response.response_code, "Found")
          response.headers.each_pair do |key, value|
            http_response.add_field key, value
          end
          http_response.body = response.payload
          http_response.send(:instance_eval, "def body; @body; end") # TODO GIANT HACK
          self.last_response = http_response
        end
      end
      #self.last_response = http.request(@raw_request) do |http_response|

        #if block
        #  chunks = []

        #  http_response.read_body do |fragment|
        #    chunks << fragment
        #    block.call(fragment)
        #  end

        #  chunked_body = chunks.join
        #end
      #end

      handle_deflation unless http_method == Net::HTTP::Head
      handle_response(chunked_body, &block)
    end
  end
end