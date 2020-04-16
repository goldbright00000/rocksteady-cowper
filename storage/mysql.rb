require '../cowper/lib/logging'

require 'sequel'
require 'yaml'

module Rocksteady
  module Storage
    module MySQL
      extend self

      #
      #   Allow users to query the config being used
      #
      def config
        {:database => @database, :username => @username, :password => @password, :hostname => @hostname, :encoding => 'utf8'}
      end


      def read_config(environment='production')
        well_known_location = '/var/hg/repos/common/config/database.yml'
        fallback_location   = '/var/hg/repos/server/config/database.yml'

        db_config = YAML.load_file(well_known_location)[environment] rescue nil

        if db_config.nil?
          db_config = YAML.load_file(fallback_location)[environment] rescue nil
        end


        if db_config.nil?
          Logging.info("WARNING: Couldn\'t read a valid #{environment} DB config from '#{well_known_location}' - falling back to default settings")

          db_config = {}

          db_config['database'] = 'rocksteady'
          db_config['username'] = 'root'
          db_config['password'] = ''
        end

        db_config['host'] = '127.0.0.1' unless db_config['host']

        return db_config['database'], db_config['username'], db_config['password'], db_config['host']
      end




      def mysql_connect(database, username, password, hostname)
        password = "" if password.nil?

        raise "You must specify the database, username, password and host" unless database && username && password && hostname

        @database = database
        @username = username
        @password = password
        @hostname = hostname

        Sequel.single_threaded = true

        @db = Rocksteady::Storage.try_connection('MySQL') {
          result = Sequel.connect("mysql2://#{@username}:#{@password}@#{hostname}/#{@database}")

          result.test_connection

          Logging.info("Connected to MySQL #{@hostname}/#{@database} as #{username}")

          result
        }

        false == @db.nil?
      end


      def connect()
        database, username, password, host = read_config()

        mysql_connect(database, username, password, host)
      end


      def connection()
        connect unless @db

        @db
      end


      def find_by_id_or_name(table_name, id)
        #
        #   The 'id' may be either the record id or the record name
        #
        id = id.gsub('\\', '\\\\') if id.class == String

        field = "id"

        Integer(id) rescue field = "name"


        s = "select * from #{table_name} where #{field} = ?"

        Rocksteady::Logging.debug(s)

        r = connection.fetch(s, id)

        return nil unless r

        Rocksteady::Logging.debug("\tReturned #{r.size} rows")

        return r.first
      end



      #
      #   Execute the raw sequel
      #
      def fetch(s)
        result = nil

        Rocksteady::Logging.debug(s)

        begin
          result = connection.fetch(s).all

          Rocksteady::Logging.debug("\tReturned #{result.size} rows")
        rescue Sequel::DatabaseDisconnectError => e
          Rocksteady::Logging.error("MySQL.fetch lost the connection to MySQL")

          Rocksteady::Logging.info("MySQL.fetch attempting to reconnect after lost connection to MySQL")

          self.connect

          Rocksteady::Logging.info("MySQL.fetch attempting retry of fetch after lost connnection to MySQL")

          retry
        rescue Exception => e
          Rocksteady::Logging.error("MySQL.fetch raised an exception #{e}")
        end

        result
      end


      #
      #   Execute the raw sequel
      #
      def execute(s)
        result = nil

        begin
          result = connection.execute(s)
        rescue Exception => e
          Rocksteady::Logging.error("MySQL.execute raised an exception #{e}")
        end
      end

    end
  end
end
