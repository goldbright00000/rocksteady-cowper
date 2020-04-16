require '../cowper/lib/logging'

require 'mongo'
require 'yaml'

Mongo::Logger.logger.level = ::Logger::WARN


module Rocksteady
  module Storage
    module MongoDB
      extend self


      def read_config(environment='production')
        yml_path = '/var/hg/repos/cowper/config/mongodb.yml'

        db_config = YAML.load_file(yml_path)[environment] rescue nil

        if db_config.nil?
          puts("\n\nWARNING: Couldn\'t read a valid #{environment} mongo config from #{yml_path} - falling back to default settings\n\n")

          #
          #   This config should be good for a simple local mongo installation
          #
          db_config = {}

          db_config['database'] = 'rocksteady'
          db_config['hostname'] = '127.0.0.1'
          db_config['port'] = '27017'
          db_config['ssl'] = false
        end


        db_config
      end


      def connect()
        result = false

        Rocksteady::Storage.try_connection('Mongo') {

          config = read_config()

          connection_string = config['atlas_connection_string']

          if connection_string
            #
            #   Use the driver config provided by Atlas
            #
            @db = Mongo::Client.new(connection_string, :database => 'rocksteady')
          else
            #
            #   Use either the default config for a local mongo installation
            #   or whatever config was specified in mongodb.yml
            #
          @db = Mongo::Client.new("mongodb://#{config['hostname']}:#{ config['port']}/?ssl=#{config['ssl']}",
                                  :database => config['database'],
                                  :user => config['username'],
                                  :password => config['password'])
          end

          @db.database_names  # force exception if we aren't connected, so try_connection again

          result = true #  We only got here if it all worked
        }

        result
      end


      def db
        @db
      end


    end


  end
end
