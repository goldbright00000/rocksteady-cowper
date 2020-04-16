require 'httparty'
require 'openssl'

require './config/default'

require './lib/logging'


module Rocksteady

  module Network
    @auth = {:username => Config.basic_auth_user, :password => Config.basic_auth_password}

    #
    #   Don't check SSL certs
    #
    Rocksteady::Logging.silence_warnings do
       NGINX_URL = Rocksteady::Config.nginx_url

       OpenSSL::SSL::VERIFY_PEER = OpenSSL::SSL::VERIFY_NONE
    end


    @headers = {
      'X-CSRF-Token' => 'jhUSTTSL5HyqrVJXxo1p+J51PDRBcgSW103s9Vnshoo=',
      'Accept-Language' => 'en-US,en;q=0.8',
      'Accept' => 'application/json'
    }


    #
    #   Send a request to (usually) the local NGINX but possibly a remote host
    #
    def self.send_post_request(url, params, host=NGINX_URL)
      response = nil

      url = URI::encode("#{host}/#{url}")

      rt = Benchmark.realtime do
        response = HTTParty.post(url, :headers => @headers, :body => params, :basic_auth => @auth)
      end

      Rocksteady::Logging.info("It took #{rt} seconds to POST to #{url} with params #{params}"[0..200])

      return [response.code, response.body]
    end



    #
    #   Some requests are sensitive to the GEO location
    #   e.g. requests to RS_Server
    #
    def self.send_get_request(url)
      url = URI::encode("#{url}")

      begin
        code = doc = nil
        response = nil

        rt = Benchmark.realtime do
          response = HTTParty.get(url, :headers => @headers)
        end

        code = response.code

        Rocksteady::Logging.info("It took #{rt} seconds to GET #{url}, returning #{code}")

        doc = response.body

      end

      return [code, doc]
    end
  end

end
