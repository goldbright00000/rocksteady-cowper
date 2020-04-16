require 'httparty'
require './storage/interface'
require './lib/status_codes'

module Rocksteady
  module AddressLabels
    extend self





    def set_packaging_container(job, container)
      job_id = job['id']

      #
      #  Set this is that the job is also updated, not just the database
      #
      job['print_request']['shipping_details']['container'] = container

      Rocksteady::Storage::Orders.set_packing_container(job_id, container)
    end





    def create_address_label(job)
      job_id = job['id']

      shipping_details = job['print_request']['shipping_details']

      shapes = Rocksteady::Services::Shapes.shapes_from_job(job)

      container = job['print_request']['shipping_details']['container']

      return {
        shipping_details: {
          name: shipping_details['name'],
          address_lines: shipping_details['address_lines'],

          container: container,
        },

        shapes: shapes,

        qr_code_data: "label||#{job_id}",
      }
    end
  end
end
