module Rocksteady
  module Services
    module Shapes
      extend self

      LOWERCASE_MY_BRAND = Rocksteady::Config.brand.downcase
      URL_HOSTNAME = Rocksteady::Config.url_hostname

      private

      def send_request_for_shape(url)

        response_code, response_string = Rocksteady::Network.send_get_request(url)

        if [Ok, Created].include? response_code
          result = JSON.parse(response_string) rescue nil

          Rocksteady::Logging.error("Could not parse the JSON for shape #{url}}") unless result
        else
          raise Rocksteady::RS_NotProcessable.new("Could not GET the shape #{url} (#{response_code}, #{response_string}")
        end

        result
      end



      #
      #   Only used if the order did not include urls
      #
      def url_for_shape(brand, id)
        target_hostname = URL_HOSTNAME.gsub(LOWERCASE_MY_BRAND, brand)

        result = "https://#{target_hostname}/api/shape/#{id}"

        Rocksteady::Logging.info("Returning shape url #{result} for #{brand}/#{id}")

        result
      end


      #
      #   Only used if the order did not include urls
      #
      def url_for_decal(brand, id)
        target_hostname = URL_HOSTNAME.gsub(LOWERCASE_MY_BRAND, brand)

        result = "https://#{target_hostname}/api/decal/#{id}"
  
        Rocksteady::Logging.info("Returning decal url #{result} for #{brand}/#{id}")

        result
      end





      public

      def shapes_from_job(job)
        shapes = job['print_request']['shapes']

        brand  = job['brand']

        result = shapes.map do |s|
          id = s['shape_id']
          decal_id = s['decal_id']

          s['shape_url'] = url_for_shape(brand, id) unless s['shape_url']
          s['decal_url'] = url_for_decal(brand, decal_id) unless s['decal_url']

          {
            quantity:  s['qty'],
            shape_url: s['shape_url'],
            decal_url: s['decal_url']
          }
        end

        result
      end


    end
  end
end
