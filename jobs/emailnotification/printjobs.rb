require 'haml'
require './lib/status_codes'
require './storage/interface'
require './jobs/emailnotification/email'

#
#   This module generates the HTML for the email which is sent
#   to the user after payment has been received. It can be
#   considered as the invoice for the purchase
#
unless File.exists?('/usr/bin/convert')
  Rocksteady::error('Please install imagemagick for the convert tool')
  exit 1
end


module Rocksteady
  module EmailNotification
    module PrintJobs
      extend self

      private

      COWPER_PUBLIC_DIR = Config.public_dir

      TEMPLATE_HAML = File.open("./views/email_notifications/on_payment.haml", 'r') {|f| f.read}


      def generate_html(r, selector_url)
        return unless r

        total_price       = r['job']['print_request']['customer_paid']

        positions         = r['job']['print_request']['shapes']

        design_url        = r['job']['print_request']['design_url']

        delivery_estimate = r['job']['print_request']['shipping_details']['delivery_estimate']

        haml_engine       = Haml::Engine.new(TEMPLATE_HAML)

        output = haml_engine.render(Object.new,
                                    total_price: total_price,
                                    selector_url: selector_url,
                                    positions: positions,
                                    design_url: design_url,
                                    delivery_estimate: delivery_estimate)
      end






      def send_invoice(r, order_dir, selector_url)
        return unless selector_url

        email_address = r['job']['print_request']['email']

        html = generate_html(r, selector_url)

        Rocksteady::Logging.info "Sending email to #{email_address} for order #{r['_id']}"

        return Rocksteady::EmailNotification.send_email(html, email_address, 'Thank you for your purchase')
      end




      def svg_to_png(shape_name, design, mask, order_dir)
        name = shape_name.gsub(' ','')

        _return = nil

        begin
          design_svg_file = "#{order_dir}/#{name}.svg"
          File.write(design_svg_file, design)

          mask_svg_file = "#{order_dir}/#{name}_mask.svg"
          File.write(mask_svg_file, mask)

          msg = `./bin/clip.sh #{order_dir}/#{name}`

          if $? != 0
            Rocksteady::Logging.warn "clip.sh returned an error #{msg}"
          else
            _return = "#{order_dir}/#{name}.png"
          end

        rescue Exception => ex

          Rocksteady::Logging.warn "svg_to_png caught an exception generating #{shape_name} in #{order_dir} - #{ex}"

        end

        _return
      end





      def bleedcut_svg(shape_id)
        record = Storage::Shapes.find_by_id(shape_id, ['bleedcut_svg']).first

        mask = record[:bleedcut_svg]
      end



      def svgs_to_pngs(order_dir, order)
        Dir.mkdir order_dir unless Dir.exists?(order_dir)

        order_id = order['_id']

        order['job']['print_request']['shapes'].each do |shape|
          begin
            shape_id   = shape['shape_id']
            shape_name = shape['position_name']

            mask = bleedcut_svg(shape_id)

            design = shape['svg']

            png_path = svg_to_png(shape_name, design, mask, order_dir)

            if png_path
              shape['url'] = Storage::url_from_public_storage(png_path)
            end
          rescue StandardError => ex
            Rocksteady::Logging.error "Could not turn svg to png processing shape #{shape_name}(#{shape_id}) for order #{order_id}"
          end
        end
      end






      def add_material_name(order, materials)
        order['job']['print_request']['shapes'].each do |shape|
          shape['material'] = materials[shape['decal_id'].to_i]
        end
      end


      def add_design_url(order)
        id  = order['job']['print_request']['design_id']
        url = Rocksteady::Storage::Designs.design_url(id)

        order['job']['print_request']['design_url'] = url
      end



      #
      #   Tell storage to write the selector and then we
      #   copy it to a publicly accessible area
      #
      def write_selector(order, public_order_dir)
        design_id = order['job']['print_request']['design_id']

        b64 = order['job']['print_request']['selector'] rescue nil

        selector = Base64.decode64(b64[22..-1]) rescue nil

        if selector

           selector_path = Rocksteady::Storage::Designs.write_selector(design_id, selector)

           `cp #{selector_path} #{public_order_dir}`
        else
           Rocksteady::Logging.error "The selector could not be written for design #{design_id}"
        end
      end



      #
      #   This is the workhorse function which generates an email from
      #   the order (JSON from the UI).  The hostname is required as
      #   we currently store the PNGs of the design locally.
      #   The PNGs are generated from the SVG in the JSON
      #
      def process_order(order, materials)
        return unless order && materials

        id            = order['_id'].to_s
        created_at    = order['job']['created_at']
        email_address = order['job']['print_request']['email']


        #
        #   Make a publicly accessible folder
        #
        public_order_dir  = Storage::Orders.mk_public_storage_path(id, created_at)

        #
        #   We don't want customers to get the high quality
        #   copy of the images so we give them PNGs
        #
        svgs_to_pngs(public_order_dir, order)


        write_selector(order, public_order_dir)

        add_design_url(order)

        url_path = public_order_dir.gsub(COWPER_PUBLIC_DIR,'')

        selector_url = "https://#{Config.url_hostname}#{url_path}/selector.png"

        add_material_name(order, materials)

        begin
          Storage::Orders.copy_dir_to_public_gcs(public_order_dir)
        rescue StandardError => e
          puts "Couldn't copy_dir_to_public_gcs while trying to send invoice for order #{id} because #{e}"
        end

        if send_invoice(order, public_order_dir, selector_url)
          Storage::Orders.mark_print_job_email_sent(id)
        else
          Rocksteady::Logging.error "Failed to send an email for order #{order['_id']}"
        end
      end




      #
      #   We need to provide the name of the material in the email
      #   The UI sends the material id only
      #
      def build_materials_map
        records = Storage::MySQL.fetch('select id, name from decals')

        Rocksteady::Logging.warn('No materials found') unless records.size > 0

        _return = {}

        records.each do |r|
          _return[r[:id]] = r[:name]
        end

        _return
      end




      public

      def send_batch_emails()
        return unless Rocksteady::EmailNotification.configured?

        records = Rocksteady::Storage::Orders.print_jobs_ready_to_email

        records = records.delete_if {|e| e['job']['brand'] != Rocksteady::Config.brand}

        Rocksteady::Logging.info "#{records.size} invoice emails to send"

        if 0 < records.size
          materials = build_materials_map


          records.each do |r|
            begin
               process_order(r, materials)
            rescue StandardError => ex
               Rocksteady::Logging.error("Couldn't process order #{r['_id']} because #{ex}")
            end
          end
        end


        Rocksteady::Logging.info "Done!"
      end

    end
  end
end


Rocksteady::EmailNotification::PrintJobs.send_batch_emails
