module Rocksteady
  module Services
    module AddressLabels
      extend self

      public

      def print_address_label(label, job_id)
        #
        #   Quick and dirty test of labels
        #
        headers = {}
        headers['Content-Type'] = 'application/json'

        auth = {
          :username => Rocksteady::Config.basic_auth_user,
          :password => Rocksteady::Config.basic_auth_password
        }


        url = URI::encode("#{Rocksteady::Config.nginx_url}/printing/address_labels/#{job_id}")

        #
        #   Now send the label onwards for generation
        #
        #
        #   Do not be tempted to do this on a thread unless you first guarantee that there is
        #   no race condition introduced between this, the client, and the sync s/ware
        #
        response = HTTParty.put(url, :headers => headers, :body => label.to_json, :basic_auth => auth)

        result = response.code >= 200 && response.code < 300

        Rocksteady::Logging.error("The address label for #{job_id} could not be printed (#{response.body})") unless result

        result
      end
    end
  end
end
