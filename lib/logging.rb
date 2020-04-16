require "slogger"


module Rocksteady
  module Logging
    extend self

    @sl = Slogger::Logger.new 'Cowper', :info, :local0

    attr_accessor :show_debug_msgs

    def bold(s)
      "\e[1m#{s}\e[m"
    end


    def _msg(message)
      message = "#{Time.now.strftime('%H:%M:%S')} #{message}"

      puts(message) if $stdout.isatty

      return message
    end


    def debug(message)
      return unless self.show_debug_msgs

      message = _msg(bold("(D) #{message}"))

      #
      #   Debug to console only
      #
      puts message
    end


    def info(message)
      message = _msg("(I) #{message}")

      @sl.info message
    end


    def warn(message)
      message = _msg("(W) #{message}")

      @sl.info message
    end


    def error(message)
      message = _msg("(E) #{message}")

      @sl.info message
    end


    def silence_warnings(&_b)
      old = $VERBOSE
      $VERBOSE=nil

      yield

      $VERBOSE = old
    end
  end
end
