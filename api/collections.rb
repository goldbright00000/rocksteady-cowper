require './lib/status_codes'

module Rocksteady
  module API
    module Collections
      extend self

      private

      def check_params!(collector, type, position, printjob_id)
        raise RS_BadParams.new('The collector name is missing') unless collector

        raise RS_BadParams.new('The QR code is not for a Decal') unless 'decal' == type

        job = Rocksteady::Orders.find_meta_by_id(printjob_id)

        raise RS_NotFound.new("The PrintJob #{printjob_id} does not exist") unless job

        status = job['status']

        raise RS_BadParams.new("The PrintJob #{printjob_id} cannot be collected because it is '#{status}'") unless Rocksteady::Orders.status_is_collectable?(status)

        position_names = Storage::Orders.decals_purchased(printjob_id).collect{|d| d[:name]}

        raise RS_BadParams.new("Position #{position} is not part of PrintJob #{printjob_id}") unless position_names.include?(position)

      end




      public

      def collect_decal(collector, type, position, printjob_id)
        check_params!(collector, type, position, printjob_id) # raises exception

        Rocksteady::Logging.info "Collector #{collector} collecting '#{position}' for order #{printjob_id}"
        return Rocksteady::BinManager.add_to_bin(printjob_id, position)
      end


      def list_bins
        Rocksteady::BinManager.all
      end

      def get_collection_status(id)
        Rocksteady::BinManager.find_by_id(id)
      end
    end
  end
end
