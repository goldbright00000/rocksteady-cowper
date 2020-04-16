require 'fileutils'
require 'json'

require '../cowper/config/default'
require '../cowper/storage/mysql'
require '../cowper/storage/mongodb'
require '../cowper/lib/status_codes'
require '../cowper/lib/logging'

#
#   See end of file for additional requires
#


module Rocksteady
  module Storage
    extend self

    PRIVATE_DIR = Config.private_dir
    PUBLIC_DIR  = Config.public_dir

    HOSTNAME    = Rocksteady::Config.url_hostname


    Design      = Struct.new(:id, :brand, :description, :email, :created_at, :updated_at, :input)

    PrintJob    = Struct.new(:id, :status, :brand, :design_id, :output, :email, :created_at, :updated_at, :shipping) do
      def to_json(*a)
        x = self.members.map{|e| "\"#{e}\": \"#{self[e]}\""}.join(',')

        "{#{x}}"
      end
    end



    def init_dirs()
      [PRIVATE_DIR, PUBLIC_DIR].each do |dir|
        begin
          FileUtils.mkdir_p(dir)
        rescue
          Logging::error("FATAL: The storage directory #{dir} could not be created")

          exit 1
        end
      end
    end



    def valid_mongo_id?(id)
      _return = (!id.nil?) and id.to_s.size > 0

      unless _return
        puts "\n\nWARNING:  You sent an invalid mongo_id \n#{caller[0]}\n#{caller[1]}\n\n"
      end

      _return
    end




    #
    #   Time stamp UTC
    #
    def add_update_time_stamp(json)

      json['updated_at'] = Time.now

      json
    end




    #
    #   Time stamp UTC
    #
    def add_create_time_stamp(json)

      json['created_at'] = Time.now

      json
    end



    def currency_code_map
      records = Storage::MySQL.fetch("select iso_numeric, symbol from currencies")

      _return = {}

      records.each do |r|
        _return[r[:iso_numeric]] = r[:symbol]
      end

      _return
    end



    def decals
      MySQL.fetch('select * from decals')
    end



    def container_characteristics
      MySQL.fetch('select * from container_characteristics')
    end




    #
    #   Used to retry the connection to MySQL, Mongo & Redis a few times on startup
    #
    def try_connection(service, &block)
      _return = nil

      sleep_time = 10

      attempts = 1

      begin
        _return = yield
      rescue => e
        Rocksteady::Logging.info "Waiting #{sleep_time} seconds for #{service} because #{e}}..."

        sleep sleep_time

        attempts += 1

        if attempts < 3
          retry
        else
          Rocksteady::Logging.error "Giving up trying to connect to #{service}"

          exit 1
        end
      end

      _return
    end



    def url_from_public_storage(path)
      "https://#{HOSTNAME}/#{path.gsub("#{PUBLIC_DIR}/", '')}"
    end


    init_dirs()

    exit(1) unless Storage::MongoDB.connect

    exit(1) unless Storage::MySQL.connect

    StoredRates = Storage::MySQL.fetch("select iso_numeric, fx_rate from currencies") rescue {}

  end
end


require '../cowper/storage/designs'
require '../cowper/storage/orders'
require '../cowper/storage/shapes'
