require 'forwardable'

require './model/notification'


module Rocksteady
  module API
    module Design
      extend Forwardable
      extend self

      def_delegators Rocksteady::Designs, :find_by_id


      #
      #   Params is really only meaningful to the RS_Server so just pass then
      #   straight to it. We store a copy for future analysis.
      #
      def create(params)
        result = nil

        Rocksteady::Logging.warn("The geo_location is missing in #{__FILE__}:#{__LINE__}") unless params['geo_location']

        Rocksteady::Logging.warn("The client_ip is missing in #{__FILE__}:#{__LINE__}") unless params['client_ip']

        Rocksteady::Logging.warn("The sub_brand is missing in #{__FILE__}:#{__LINE__}") unless params['sub_brand']


        result = Rocksteady::RS_Server.create_design(params)

        if result
          Rocksteady::Designs.create(params, result)

          Rocksteady::Notification::design_created(params)
        else
          Rocksteady::Logging.error("Could not create a design for #{params}")
        end

        result
      end



      def update(id, design)
        code = Rocksteady::Designs.update(id, design)
      end

    end
  end
end
