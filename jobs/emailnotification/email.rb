require 'fileutils'
require 'haml'
require 'socket'
require 'mandrill'

require './lib/logging'
require './storage/interface'
require './config/default'



module Rocksteady
  module EmailNotification
    #
    #   This module provides common functionality for the modules
    #   which do the work of figuring out what to send
    #
    extend self


    @api_key = Rocksteady::Config.mandrill_key

    @mandrill = Mandrill::API.new @api_key


    def create_message(email_address, subject, html)
      {
            :subject=> subject,
	    :from_name=> Rocksteady::Config.brand,
            :text=>"",
            :to=>[
                  {
                    :email=> "#{email_address}",
                    :name=> "#{email_address}"
                  }
                 ],
            :html=> html,

	    :from_email=>"noreply@#{Rocksteady::Config.brand}.com"
      }
    end



    #
    #   Mandril seems to throw an exception or
    #   return a message in 'reject_reason'. If
    #   we return True from this then we know
    #   that Mandril accepted the message for
    #   delivery so it isn't our problem ...
    #
    def accepted_by_mandrill(message)
      result = false

      begin
         response = @mandrill.messages.send message

         Rocksteady::Logging.warn("Mandrill could not send an email becuase #{response[0]['reject_reason']}") if response[0]['reject_reason']

         result = (nil == response[0]['reject_reason'])
      rescue Exception => ex
         Rocksteady::Logging.error "The message was not accepted_by_mandrill because #{ex}"
      end

      result
    end


    public

    def configured?
      result = @api_key.size > 0

      Rocksteady::Logging.info "Not sending emails as Mandril is not configured" unless result

      result
    end



    def send_email(html, email_address, subject)
      _return = false

      if @api_key.size == 0
         Rocksteady::Logging.warn("You must provide a mandrill api key")
      else
        begin
          message = create_message(email_address, subject, html)

          mandrill_response = accepted_by_mandrill(message)

          if mandrill_response
            _return = true
          else
            Rocksteady::Logging.error("Could not send email to #{email_address}")
          end

        rescue Mandrill::InvalidKeyError => e
           Rocksteady::Logging.warn "The mandrill email key is not valid"

        rescue Exception => e
          # Mandrill errors are thrown as exceptions
          puts "A mandrill error occurred: #{e.class} - #{e.message}"
          raise
        end
      end


      #
      #   Returning true allows something else to mark this email as 'sent'
      #
      _return

    end
  end
end
