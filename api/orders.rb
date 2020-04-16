require 'forwardable'

module Rocksteady
  module API
    module Orders
      extend Forwardable
      extend self

      public

      def_delegators Rocksteady::Storage::Orders, :find_by_id, :recent_interesting

      def new(params)
        Rocksteady::Orders.new(params)
      end

    end
  end
end
