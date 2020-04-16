require './lib/status_codes'

module Rocksteady
  module API
    module Packing
      extend self

      private


      public

      def packaging_instructions(bin)
        begin
          job = Rocksteady::Orders.find_by_id(bin.print_job_id)

          container = Rocksteady::Containers.suggest_containers_for_job(job)

          Rocksteady::Logging.info "Order #{bin.print_job_id} fits in container #{container}."

          result = {
            bin: bin,

            container: container,

            shipping_details: job['print_request']['shipping_details']
          }

        rescue => ex
          #
          #   If an error occurs, move the status back to collected so that
          #   we can try again
          #
          Rocksteady::Orders.move_status(bin.print_job_id, 'Packing', 'Collected')

          raise Rocksteady::RS_InternalError.new "There was a problem with packaging_instructions for order #{bin.print_job_id} in bin #{bin.id} - Check if Dawson is running. (#{ex})"

          result = nil
        end

        result
      end



      def next_to_pack
        result = nil

        bin = Rocksteady::BinManager.next_to_pack

        if bin
          Rocksteady::Logging.info "Bin #{bin.id} containing #{bin.print_job_id} is ready to pack."

          result = packaging_instructions(bin)
        else
          Rocksteady::Logging.info "Well done! Everything is packed."
        end

        result
      end


      #
      #   To send an order back to sorting we:
      #
      #      1.  Empty the bin
      #      2.  Set the order status to 'Printed'
      #
      def return_to_sorting_table(id)
        result = false

        bin = Rocksteady::BinManager.find_by_id(id)

        if bin
          print_job_id = bin.print_job_id

          Rocksteady::BinManager.empty_bin(bin)

          #
          #   Abandon packing puts everything back to the sorting table
          #
          Rocksteady::Orders.mark_as_printed(print_job_id)

          result = true
        end

        result
      end



      def start_packing(packer_name, bin_id)
        result = false

        bin = Rocksteady::Packing.check_params(packer_name, bin_id) # raises exception

        if bin
          Rocksteady::Logging.info "Packer #{packer_name} started packing print_job_id #{bin.print_job_id} in bin #{bin_id}"

          Rocksteady::BinManager.empty_bin(bin)
          #
          #   The job is now 'Packed'
          #
          Rocksteady::Orders.mark_as_packed(bin.print_job_id)

          result = true
        end

        result
      end


    end
  end
end
