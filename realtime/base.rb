require 'httparty'
require 'json'
require "bunny"
require 'daemons'
require './lib/logging'
require './config/default'
require './storage/interface'

module Rocksteady
   module MQ
    module Base
      extend self


      def init_queue(process_name, event_name)
        connection = Bunny.new
        connection.start

        channel = connection.create_channel
        xchange = channel.topic("cowper", :durable => true)
        queue   = channel.queue(process_name, :durable => true)

        queue.bind(xchange, :routing_key => "cowper.#{event_name}.msg")

        return connection, channel, queue
      end



      def _run(process_name, event_name, manually_ack)
        Logging.info "MQ #{Process.argv0} starting as process #{Process.pid}"

        connection, channel, queue = init_queue( process_name, event_name)

        begin
          queue.subscribe(:block => true, :manual_ack => manually_ack) do |delivery_info, properties, msg|
            ok = handle JSON.parse msg

            #
            #   If the handler throws an exception then we never get here
            #   which causes the message to be processed when the client
            #   starts up again.
            #
            if manually_ack && ok
              channel.ack(delivery_info.delivery_tag)
            end
          end
        rescue Interrupt
          #
          #   CTRL-C when not running as a Daemon
          #
          Logging.info "MQ #{Process.argv0} exiting process #{Process.pid} as requested"
        ensure
          Logging.error "MQ #{Process.argv0} tidyup process #{Process.pid}"

          channel.close
          connection.close
        end

      end



      def sleep_awhile
        awhile = 5

        Logging.error "MQ #{Process.argv0} sleeping for #{awhile}"

        sleep awhile
      end



      public

      DesignCreated      = 'design_created'
      DesignUpdated      = 'design_updated'
      PurchaseWin        = 'purchase_win'
      AddDesignToLibrary = 'library_add'


      def run(process_name, event_name, manually_ack = false)
       Daemons.run_proc(process_name, {:dir_mode => :normal,
                                        :dir => '/var/hg/repos/cowper/tmp/pids',
                                        :log_dir => '/var/hg/repos/cowper/log',
                                        :log_output => true}) do

          #
          #  NB: self is not this module, it is the one extending this module
          #
          self._run(process_name, event_name, manually_ack) rescue sleep_awhile && retry
       end
      end
    end
  end
end
