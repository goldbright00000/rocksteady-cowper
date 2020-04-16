module Rocksteady
  module API
    module AddressLabels
      extend self

      public

      def generate(job, container)
        container = 'Z' unless container

        job_id = job['id']

        Rocksteady::AddressLabels.set_packaging_container(job, container)

        label = Rocksteady::AddressLabels.create_address_label(job)

        if label

          if Rocksteady::Services::AddressLabels.print_address_label(label, job_id)
             Rocksteady::Logging.info("Generated label for #{label}")
	  else
             Rocksteady::Logging.error("Could not generate label for #{label}")
          end
        end

        label
      end
    end
  end
end
