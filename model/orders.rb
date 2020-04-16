require 'forwardable'
require './storage/interface'
require './lib/status_codes'

require './config/default'


module Rocksteady
  module Orders
    extend Forwardable
    extend self

    def_delegators Rocksteady::Storage::Orders, :find_by_id, :find_meta_by_id, :update_status, :recent_interesting, :move_status, :exists?, :status


    @currencies = Storage.currency_code_map

    @auth = {:username => 'rockSteady', :password => 'Simpsons'}

    @headers = {
      'Accept-Language' => 'en-US,en;q=0.8',
      'Accept' => 'application/json'
    }



    #
    #   Check that the id refers to a real design
    #
    def design_id_exists?(json)
      design_id = json['print_request']['design_id']

      design = Storage::Designs.find_by_id(design_id)

      design.nil? ? false : true
    end




    #
    #   Check that the json contains the correct keys as a basic
    #   test of compatibility
    #
    def validate_structure(json)
      return false unless json['print_request']

      pr = json['print_request']

      #
      #   Check that the request contains only these fields
      #
      return false if [] != pr.keys - ['id', 'design_id', 'shapes', 'email', 'total_cost', 'shipping_details', 'selector', 'discount_code']

      #
      #   Check that the shipping_details contain no fields other than these
      #
      return false if [] != pr['shipping_details'].keys - ['name', 'address_lines', 'city', 'country', 'delivery_estimate', 'container', 'telephone', 'expedited_shipping']

      #
      #   Expedited shipping keys should be 'provider' and 'service'
      #
      return false if pr['shipping_details']['expedited_shipping'] && pr['shipping_details']['expedited_shipping'].keys != ['provider', 'service']


      return false unless pr['shapes'].class == Array

      shapes = pr['shapes']

      #
      #   Check that each shape has these keys at a minimum
      #
      return false unless shapes.all?{|s| [] == ['position_name', 'shape_id', 'decal_id', 'decal_price', 'qty', 'svg', 'colour_map'] - s.keys}


      return true
    end





    def log_new_print_request(job_id, job)
      pr  =  job['print_request']

      email_address = pr['email']

      postal_address = pr['shipping_details']

      total_cost = pr['total_cost']

      dc = pr['discount_code']

      Rocksteady::Logging.info "Got an order #{job_id} for #{email_address} from #{postal_address}. Total cost is #{total_cost} using discount code (#{dc})"
    end




    #
    #   Add a new print job, updating the owner of the design - dod
    #
    #
    def new(json)
      raise RS_Error.new(NotProcessable), 'The print request is not semantically correct' unless validate_structure(json)

      raise RS_Error.new(Forbidden), 'The print job references a Design which could not be found' unless design_id_exists?(json)

      id, job = Storage::Orders.add(json)

      log_new_print_request(id, job)

      return id, job
    end



    def add_urls_to_shapes(json)
      url_hostname = Rocksteady::Config.url_hostname

      shapes = json['print_request']['shapes']

      shapes.map! do |s|
        s['shape_url'] = "https://#{url_hostname}/api/shape/#{s['shape_id']}"
        s['decal_url'] = "https://#{url_hostname}/api/decal/#{s['decal_id']}"

        s
      end

      return json
    end



    def update(id, json)
      raise RS_Error.new(NotProcessable), 'The print request is not semantically correct' unless validate_structure(json)

      raise RS_Error.new(Forbidden), 'The print job references a Design which could not be found' unless design_id_exists?(json)

      json = add_urls_to_shapes(json)

      job = Storage::Orders.update(id, json)

      return job
    end





    #
    #   Mark payment as done if we can
    #
    def attempt_payment(print_id, customer_paid, numeric_currency_code)
      job = Storage::Orders.find_by_id(print_id) rescue nil

      unless job
        Rocksteady::Logging.error("Got a payment attempt for a Print Request (#{print_id}) that does not exist")

        return
      end


      status = 'Payment Received'

      job['print_request']['customer_paid'] = "#{@currencies[numeric_currency_code]}#{customer_paid}"

      Storage::Orders.update(print_id, job)

      job = Storage::Orders.update_status(print_id, status)

      return job
    end





    def payment_failed(print_id)
      job = Storage::Orders.find_by_id(print_id)

      unless job
        Rocksteady::Logging.warn "Cowper got a failure echo response for a Job (#{print_id}) that doesn't exist"

        return
      end

      status = "Payment Failed"

      Storage::Orders.update_status(print_id, status)
    end



    def status_is_collectable?(status)
      #
      #   'Payment Received' is there so that manually created PDFs can
      #   also be collected
      #
      ['Payment Received', 'Printed', 'Ready To Print', 'Collecting'].include?(status)
    end


    def mark_as_packed(id)
      move_status(id, 'Packing', 'Packed')
    end


    def mark_as_collected(id)
      move_status(id, 'Collecting', 'Collected')
    end


    def mark_as_printed(id)
      #
      #  Update rather than move as we can be in several different
      #  prior states
      #
      update_status(id, 'Printed')
    end


    def container(job_id)
      Storage::Orders.container(job_id)
    end

  end
end
