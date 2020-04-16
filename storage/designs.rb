require 'erb'
require 'oj'
require 'fog/google'

require '../cowper/storage/interface'
require '../cowper/storage/google_cloud_services'
require '../cowper/lib/status_codes'
require '../cowper/lib/logging'



module Rocksteady
  module Storage
    module Designs
      extend self

      @hostname = Rocksteady::Config.url_hostname

      @designs = Storage::MongoDB.db[:designs]

      @designs.indexes.create_many([{
                                      :key => {'design.email' => 1}
                                    },
                                    {
                                      :key => {'design.emailed_customer' => 1}
                                    },
                                    {
                                      :key => {'design.created_at' => 1}
                                    },
                                    {
                                      :key => {'design.updated_at' => 1}
                                    }])



      def dump(id)
        ap find_metadata_by_id(id)
      end



      def read_from_fs(path)
        result= IO.read("#{path}/design.json") rescue nil
      end



      def find_by_id(id)
        raise "You must provide an id" unless Storage.valid_mongo_id?(id)

        path = private_storage_path(id)

        result = nil
        result = GCS.load_design(path)
        result = read_from_fs(path) unless result

        result
      end




      def find_metadata_by_id(id)
        raise "You must provide an id" unless Storage.valid_mongo_id?(id)

        result = @designs.find('_id' => BSON::ObjectId(id)).to_a.first rescue nil

        if result
          add_default_brand_if_required(result)
        end

        result
      end



      def insert_or_die(design)
        result = @designs.insert_one('design' => design)

        result.inserted_id.to_s
      end


      #
      #   Initial save of metadata to Mongo
      #
      def save_metadata(params, doc)
        t_now       = Time.now.to_i

        revision    = doc['order_kit']['revision'] rescue 'missing'
        description = doc['order_kit']['description'] rescue 'missing'

        #
        #   Adding the brand here isn't unsafe as this is when the kit is being
        #   saved for the very first time.  It would be difficult to see how the
        #   client for one brand could be connected to a server for another.
        #
        design = {
          brand:       Config.brand,
          description: description,
          input:       params,
          storage:     "host:#{@hostname}",
          rev:         revision,
          updated_at:  t_now,
          created_at:  t_now,
        }

        #
        #  NB kit wants string keys
        #
        doc['created_at'] = doc['updated_at'] = t_now

        mongo_id = nil

        rt = Benchmark.realtime do
          mongo_id = insert_or_die(design)
        end

        Logging.info "Saving design to Mongo took #{rt}"

        return mongo_id
      end



      def add_id_to_design(id, design)
        #
        #   Need to make sure that the MongoID is in the kit
        #
        design['order_kit']['id'] = id

        design['positions'].each {|p| p['kit_id'] = id }
      end



      def save_to_local_fs(path, design)
        bytes_written = 0

        rt = Benchmark.realtime do
          bytes_written = IO.write("#{path}/design.json", design)
        end

        Logging.info "Saving #{bytes_written} bytes for design to local file #{path} took #{rt}"
      end




      def save_to_gcs(path, design, m_time, blocking_write)
        GCS.save_design(path, design, m_time, blocking_write)
      end



      #
      #   Write the design as a JSON doc locally and to a remote Google bucket
      #
      def save_json(id, design, blocking_write = false)
        json = Oj.dump(design)

        path = mk_private_storage_path(id)

        save_to_local_fs(path, json)

        save_to_gcs(path, json, m_time = Time.now.to_i, blocking_write)
      end




      #
      #   The doc comes in as a hash, metadata gets stored in the database
      #   Some metadata is stored in Mongo and the JSON string is written
      #   to storage (disk now)
      #
      def save(params, doc)
        id = save_metadata(params, doc)

        #
        #   We only need to do this on initial creation
        #
        add_id_to_design(id, doc)

        save_json(id, doc, blocking_write = true)

        Logging.info "Created Design #{id}"

        #
        #   This is the MongoID
        #
        id
      end



      #
      #   Updates to the metadata
      #
      def update_metadata(metadata, doc, t_now)
        t_now = Time.now.to_i

        email = doc['email'] rescue 'Not given'

        revision    = doc['order_kit']['revision'] rescue 'missing'

        updates = {
          'design.email'      => email,
          'design.updated_at' => t_now,
          'design.storage'    => "host:#{@hostname}",
          'design.rev'        => revision,
          'design.brand'      => Config.brand,
        }

        status = @designs.update_one(
          {
            :_id => metadata['_id']
          },

          '$set' => updates
        )

        id = metadata['_id'].to_s
        metadata = Storage::Designs.find_metadata_by_id(id)

        raise "An update to the metadata failed for #{id}" unless metadata['design']['updated_at'] == t_now
      end






      def update_json(metadata, design, t_now)
        id    = metadata['_id'].to_s
        path  = mk_private_storage_path(id)

        design['updated_at'] = t_now

        json = Oj.dump(design)

        save_to_local_fs(path, json)

        save_to_gcs(path, json, t_now, blocking_write = false)
      end




      def update(metadata, doc)
        raise "The update looks invalid" unless doc.keys.include?('order_kit')

        _return = false

        t_now = Time.now.to_i

        update_metadata(metadata, doc, t_now)

        update_json(metadata, doc, t_now)

        _return = true

        #
        #   TBD:  Make this update also consider FS updates
        #
        _return
      end





      def days_ago_to_timestamp(num)
        time_now = Time.now.to_i

        result = time_now - (86400 * num)


      end

      #
      #   List the fields specified in the find() query below ...
      #
      def recent_interesting
        t_start  = days_ago_to_timestamp(Config.recent_means)

        updated_since(t_start)

      end



      def add_default_brand_if_required(design)
        design['brand'] = "Motocal" unless design['brand']
      end




      #
      #   This is used to provide a list of recently built kits for
      #   things like the kit build report.
      #
      def updated_since(unix_timestamp)

        records = @designs.find({'design.updated_at' => {'$gt' => unix_timestamp}})

        result = records.map do |record|
          design          = record['design']

          #
          #   Assume that kits without brand information are Motocal. This is
          #   the safest assumption to make.
          #
          add_default_brand_if_required(design)

          d               = Design.new

          d.id            = record['_id'].to_s
          d.email         = design['email']
          d.description   = design['description']
          d.created_at    = design['created_at']
          d.updated_at    = design['updated_at']
          d.input         = design['input']
          d.brand         = design['brand']

          d
        end

        result
      end




      #
      #   Return a directory where this design can
      #   be stored.  NB we shard the MongoId so that
      #   a new directory gets created every few days
      #
      def private_storage_path(id)
        raise Rocksteady::Logging.error("The id:#{id} is null") unless id

        raise 'I need a design id' unless id

        dir = "#{PRIVATE_DIR}/designs/#{id[0..4]}/#{id}"
      end



      def mk_private_storage_path(id)
        dir = private_storage_path(id)

        FileUtils.mkdir_p dir

        dir
      end



      def public_storage_path(id, created_at)
        raise Rocksteady::Logging.error("Either id:#{id} or created_at:#{created_at} are null") unless id && created_at

        "#{PUBLIC_DIR}/designs/#{id[0..4]}/#{id}#{created_at}"
      end



      def mk_public_storage_path(id, created_at)
        dir = public_storage_path(id, created_at)

        FileUtils.mkdir_p dir

        dir
      end




      def write_selector(id, selector, metadata = nil)

        raise Rocksteady::RS_InternalError.new('write_selector: expected a png') unless selector
        raise Rocksteady::RS_InternalError.new('write_selector: expected a string png') unless String == selector.class

        metadata = Storage::Designs.find_metadata_by_id(id) unless metadata

        raise Rocksteady::NotFound.new("The kit #{id} could not be found") unless metadata

        created_at = metadata['design']['created_at']

        dir = mk_public_storage_path(id, created_at)

        selector_path = "#{dir}/selector.png"

        begin
          File.open("#{dir}/selector.png", 'wb') {|f| f.write selector}

          GCS.copy_selector(dir)

        rescue StandardError => e
          Rocksteady::Logging.warn("Unable to create selector.png for #{dir} because #{e}")
        end

        return selector_path
      end



      def update_selector(id, selector)
        return unless selector

        write_selector(id, selector)
      end



      def design_url(id)
        "https://#{HOSTNAME}/app/#/kits/-/-/-/-/#{id}/selector-map"
      end

    end
  end
end