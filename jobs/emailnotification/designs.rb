require './model/designs'
require './jobs/emailnotification/email'

module Rocksteady
  module EmailNotification
    module Designs
      extend self

      HOSTNAME      = Rocksteady::Config.url_hostname
      TEMPLATE_HAML = File.open("./views/email_notifications/on_design_email.haml", 'r') {|f| f.read}



      def generate_html(design_url, selector_url)
        raise 'I need a design' unless design_url && selector_url

        haml_engine = Haml::Engine.new(TEMPLATE_HAML)


        output = haml_engine.render(Object.new,
                                    selector_url: selector_url,
                                    design_url: design_url,
                                    hostname: HOSTNAME)
      end





      def process(metadata, email_address)
        id            = metadata['_id'].to_s
        created_at    = metadata['design']['created_at']

	subject       = "Your #{Rocksteady::Config.brand} Design"

        path = Rocksteady::Storage::Designs.mk_public_storage_path(id, created_at)

        selector_url = Storage::url_from_public_storage(path)

        selector_url = "#{selector_url}/selector.png"

        design_url = Rocksteady::Storage::Designs.design_url(id)

        html = generate_html(design_url, selector_url)

        if email_address && email_address.include?('@')
          Rocksteady::EmailNotification.send_email(html, email_address, subject)
        end
      end




      public

      def send_one_email(id, email_address)
        return unless Rocksteady::EmailNotification.configured?

        design_metadata = Storage::Designs.find_metadata_by_id(id)

        Rocksteady::Logging.error("The Design #{id} could not be found") unless design_metadata

        process design_metadata, email_address
      end
    end
  end
end
