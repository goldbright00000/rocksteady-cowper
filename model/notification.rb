require 'bunny'
require './config/default'


module Rocksteady
  module Notification
    extend self


    def init
      @conn = try_connection('RabbitMQ') do
         conn = Bunny.new()
         conn.start
         conn
      end

      @channel = @conn.create_channel
      @xchange = @channel.topic("cowper", :durable => true)
    end





    def try_connection(service, &block)
      _return = nil

      sleep_time = 10

      attempts = 1

      begin
        _return = yield
      rescue
        Rocksteady::Logging.info "Waiting #{sleep_time} seconds for #{service} ..."

        sleep sleep_time

        attempts += 1

        if attempts < 30
          retry
        else
          Rocksteady::Logging.error "Giving up trying to connect to #{service}"

          exit 1
        end
      end

      _return
    end




   def publish(params, key, is_json=false)
      return unless @xchange

        k = "cowper.#{key}.msg"

        if is_json
          msg = params
        else
          msg = params.to_json
        end

      @xchange.publish(msg, :routing_key => k, :persistent => true)
    end



    def purchase_win(params)
      publish params, :purchase_win
    end


    def new_print_request(params)
      publish params, :new_print_request, is_json = true
    end


    def design_created(params)
      publish params, :design_created
    end


    def design_update(params)
      publish params, :design_updated
    end


    def add_to_library(params)
      publish params, :library_add, is_json = true
    end

  end
end


Rocksteady::Notification.init if Rocksteady::Config.send_notifications
