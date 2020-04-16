require './lib/logging'
require './storage/interface'
require './lib/network'
require './config/default.rb'


module Rocksteady
  module PDFs
    extend self


    #
    #   If the cuts are not present in the database then
    #   we continue so that the job appears in the print
    #   queue but with a status indicating that there is
    #   a problem. The customer may be refunded or we
    #   may correct the problem and reprint the Design
    #
    def add_cuts_to(shape)
      result = false

      shape_id   = shape['shape_id']

      shape_info = Storage::Shapes.find_by_id(shape_id, ['bleedcut_svg', 'kisscut_svg', 'throughcut_svg']) rescue nil

      if shape_info.class == Array and shape_info.first
        raise Rocksteady::RS_Inconsistent("Too many shapes were found for #{shape_id}") if shape_info.size > 1

        shape_info = shape_info.first

        throughcut_svg = shape_info[:throughcut_svg]
        kisscut_svg    = shape_info[:kisscut_svg]
        bleedcut_svg   = shape_info[:bleedcut_svg]

        if throughcut_svg && kisscut_svg && bleedcut_svg
          shape['throughcut_svg'] = throughcut_svg
          shape['kisscut_svg']    = kisscut_svg
          shape['bleedcut_svg']   = bleedcut_svg

          result = true
        else
          Rocksteady::Logging.warn(" Could not find cuts for #{shape_id}")
        end

      end

      result
    end



    #
    #   Trigger the POST to Dundrum and determine how to
    #   handle the response.
    #
    def send_shape_to_pdf_server(url, params)
      result = false

      begin
        response = Network.send_post_request(url, params)

        result = (response[0] == 201)

        Rocksteady::Logging.warn "Dundrum said #{response}" unless result

      rescue Net::ReadTimeout
        Rocksteady::Logging.error "Dundrum timed out"

        result = false

      rescue Errno::ECONNREFUSED
        Rocksteady::Logging.warn "Dundrum may not be running"

        result = false
      end

      result
    end




    #
    #   Returns true to indicate all shapes were sent to the PDF server
    #   Returns false if any fail
    #
    def send_shapes_to_pdf_server(id, shapes)
      return false unless shapes

      result = true

      url = '/pdf'

      shapes.each do |shape|

        params = {
          :design_id => id,
          :shape => shape
        }

        result = add_cuts_to(shape) && send_shape_to_pdf_server(url, params)

        break unless result

        Rocksteady::Logging.info("Printed #{shape['position_name']}") rescue nil
      end

      result
    end




    #
    #   Sends each shape in turn to the PDF server
    #   Returns true iff all sent correctly
    #
    def generate_pdf(id, json)
      result = 'PDF Generation Failed'

      begin
        h = Storage::Shapes.read_from_storage(json)

        shapes = h['shapes'] rescue nil

        if send_shapes_to_pdf_server(id, shapes)
          result = 'Ready To Print'
        end

      rescue Net::ReadTimeout
        Rocksteady::Logging.warn "Timeout while processing #{id}, requeuing ..."

      rescue RuntimeError => ex

        Rocksteady::Logging.warn  ex

      end

      result
    end





    def copy_to_s3
      s3_bucket = Rocksteady::Config.s3_print_bucket

      if s3_bucket
        Rocksteady::Logging.info "Starting to move files to S3"

        gsutil = Rocksteady::Config.gsutil

        s = `#{gsutil} mv -c /var/hg/repos/dundrum/public/Folder* s3://#{s3_bucket}/`

        unless $?.success?
          Rocksteady::Logging.warn "Failed to move files to S3 because #{s}"
        end
      else
        Rocksteady::Logging.info "No S3 config so skipping that step"
      end

    end



    def process_job(r)

      id = r['_id'].to_s
      status = ''

      Rocksteady::Logging.info " Generating #{id}"

      status = generate_pdf(id, r)

      if 'Ready To Print' == status

        Storage::Orders.mark_print_job_pdf_generated(id)

        #copy_to_s3
        
      end

      Rocksteady::Logging.info " Status of #{id} is '#{status}'"

      Storage::Orders.update_status(id, status)
    end



    def process_jobs(jobs)
      Rocksteady::Logging.info "Starting generate_pdfs for #{jobs.size} orders"


      jobs.each do |r|
        process_job(r) rescue puts "Job failed"
      end

      Rocksteady::Logging.info "Finished generate_pfs"
    end


    #
    #   Remove any jobs which aren't for my brand
    #
    def remove_jobs_for_other_brands(jobs)
      my_brand = Config.brand

      jobs.delete_if {|r|
        id    = r['_id']
        brand = r['job']['brand']

        result = my_brand != brand

        Rocksteady::Logging.info "Skipping print job #{id} because it is for #{brand} and I'm #{my_brand}" if result

        result
      }

      jobs
    end


    def prioritize_new!(jobs)
       jobs.sort!{|a, b| b['job']['status'] <=> a['job']['status']}
    end	



    def generate_pdfs
      jobs  = Storage::Orders.ready_to_generate_pdf
      jobs += Storage::Orders.pdf_generation_failed

      jobs = remove_jobs_for_other_brands(jobs)

      prioritize_new! jobs

      if jobs.size > 0
        process_jobs(jobs)
      end

    end

  end
end


Rocksteady::PDFs.generate_pdfs
