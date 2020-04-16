module Rocksteady
  module RS_Server
    extend self

    public


    def create_design(params)
      result = nil

      response_code, response_string = Rocksteady::Network.send_post_request('order_kits', params)

      if [Ok, Created].include? response_code
        result = JSON.parse(response_string) rescue nil

        Rocksteady::Logging.error("Could not parse the JSON for design with #{params}") unless result
      else
        raise Rocksteady::RS_NotProcessable.new("Could not create a design with #{params}")
      end

      result
    end

  end
end
