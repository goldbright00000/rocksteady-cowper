module Rocksteady
  module ExceptionHandler
    extend self

    #
    #   We return a msg to the client and log to stdout
    #
    def handle_error(ex)
      if ex.kind_of? Rocksteady::RS_Error
        status = ex.code

        msg = "\n    RS_Error #{ex}\n " + ex.backtrace[0..6].join("\n   ") +"\n\n"
        #
        #   For our own RS_Error exceptions, we want
        #   to return them as JSON
        #
        _return = ex.to_json
      else

        _return = ex.to_s

        #
        #   Short message for the log
        #
        msg = "\n   #{_return}\n   " + ex.backtrace[0..6].join("\n   ") +"\n\n"
      end

      puts msg

      #
      #   Sinatra sends this to the client
      #
      return status, _return
    end

  end
end
