require '../cowper/lib/status_codes'
require '../cowper/config/default'

module Rocksteady
  module Storage
    module Orders
      extend Forwardable
      extend self

      def_delegators Rocksteady::Storage::GCS, :copy_dir_to_public_gcs


      @print_jobs = Storage::MongoDB.db[:print_jobs]

      @print_jobs.indexes.create_many([{
                                         :key => {'job.print_request.email' => 1},
                                       },
                                       {
                                         :key => {'job.status' => 1},
                                       },
                                       {
                                         :key => {'job.created_at' => 1},
                                       },
                                       {
                                         :key => {'job.updated_at' => 1}
                                       }])


      @valid_status = ['Awaiting Payment',
                       'Payment Received', 'Payment Needs Review', 'Payment Failed',
                       'Ready To Print', 'PDF Generation Failed', 'Printed',
                       'Collecting',
                       'Collected',
                       'Packing',
                       'Packed']




      #
      #  id is returned as a String - nobody should know about BSON
      #
      def add(request)
        request['status']     = 'Awaiting Payment' unless request['status']
        request['updated_at'] = request['created_at'] = Time.now
        request['brand']      = Config.brand

        #
        #  Remove the redundant 'shapes' array as it isn't stored in Mongo
        #
        request['print_request'].delete('shapes')

        result = @print_jobs.insert_one({'job' => request})

        return result.inserted_id.to_s, request
      end





      #
      #  Read the shapes from GCS or the local f.s.
      #
      def add_shapes(json)
        begin
          shapes = Shapes.read_from_storage(json)

          json['job']['print_request']['shapes'] = shapes['shapes']

        rescue Exception => ex
          Rocksteady::Logging.error(ex.to_s)
          json = nil
        end

        json
      end



      def decals_purchased(printjob_id)
        j = find(id: printjob_id).first

        result = j['job']['print_request']['shapes'].map do |s|
          {
            name:                      s['position_name'],
            total_ordered:             s['qty'],
            qty_remaining_to_collect:  s['qty'],
          }
        end

        result
      end




      def add_default_brand_if_required(job)
        brand = job['brand']

        job['brand'] = "Motocal" unless brand

        job
      end


      #
      #  Find by id or by other search params
      #  Options allows us to ignore some field - notably the svg data
      #
      def find(params, options=[])
        if params.keys == [:id]
          id = params[:id]

          result = @print_jobs.find('_id' => BSON::ObjectId(id)).to_a rescue [nil]
        else
          result = @print_jobs.find(params).to_a
        end

        if options.include?(:no_svg_data)
          result[0]["job"]["print_request"]["selector"] = nil
        end

        #
        #   Early exit if we found nothing. We forced find to always return an array
        #
        return [] if [nil] == result


        #
        #   Add svg data if required
        #
        unless options.include?(:no_svg_data)
          result = result.map do |j|
            j = add_shapes(j)
          end
        end

        result = result.delete_if{|e| nil == e}

        #
        #   Add brand if it isn't already recorded
        #
        result = result.map do |j|
          _id = j['_id']

          job = add_default_brand_if_required(j['job'])

          {'_id' => _id, 'job' => job}
        end

        result
      end





      def find_first(params, options=[])
        result = find(params, options)

        result = result.first if result

        result
      end




      def exists?(id)
        raise "You must provide an id" unless Storage.valid_mongo_id?(id)

        return false unless Storage.valid_mongo_id?(id)

        #
        #   This should be fast as Mongo can use a covering query
        #
        1 == @print_jobs.find({:_id => BSON::ObjectId(id)}, :fields => ['_id']).limit(1).count rescue false
      end




      def find_by_id(id, *options)
        result = self.find({id: id}, options)

        if result
          #
          #   Add the id as a key to the hash
          #
          result[0]['job']['id'] = id rescue nil

          result = result[0]['job'] rescue nil
        end

        result
      end



      def find_meta_by_id(id)
        self.find_by_id(id, :no_svg_data)
      end



      def status(id)
        raise "You must provide an id" unless Storage.valid_mongo_id?(id)

        return false unless Storage.valid_mongo_id?(id)

        #
        #   This should be fast as Mongo can use a covering query
        #
        r = @print_jobs.find({:_id => BSON::ObjectId(id)}, :fields => ['job.status']).first

        r['job']['status']
      end




      def valid_status?(s)
        return @valid_status.include?(s)
      end



      def update_status(id, status)
        raise "You must provide an id" unless Storage.valid_mongo_id?(id)

        raise "The order #{id} does not exist" unless exists?(id)

        raise "The status (#{status}) is not valid for order #{id}" unless valid_status?(status)

        @print_jobs.update_one({:_id => BSON::ObjectId(id)},
                               '$set' => {
                                 'job.status' => status,
                                 'job.updated_at' => Time.now
                               })

        return find_by_id(id)
      end

      #
      # Status is #<Mongo::Operation::Result:47425830396160 documents=[{"ok"=>1, "nModified"=>1, "n"=>1}]>
      #
      def set_packing_container(id, container)
        raise "You must provide an id" unless Storage.valid_mongo_id?(id)

        status = @print_jobs.update_one({:_id => BSON::ObjectId(id)},
                                        '$set' => {
                                          'job.print_request.shipping_details.container' => container,
                                          'job.updated_at' => Time.now
                                        })

        return status
      end



      def update(id, doc)
        raise "You must provide an id" unless Storage.valid_mongo_id?(id)

        Shapes.write_to_storage(id, doc)

        Storage.add_update_time_stamp(doc)

        @print_jobs.update_one({:_id => BSON::ObjectId(id)},
                               '$set' => {'job.print_request' => doc['print_request']})

        return find_by_id(id)
      end




      def private_storage_path(id)
        dir = "#{PRIVATE_DIR}/print_requests/#{id}"

        FileUtils.mkdir_p dir

        dir
      end




      def public_storage_path(id, created_at)
        ts_created_at = created_at.to_i

        "#{PUBLIC_DIR}/print_requests/#{id}#{ts_created_at}"
      end




      def mk_public_storage_path(id, created_at)
        dir = public_storage_path(id, created_at)

        FileUtils.mkdir_p dir

        dir
      end



      def shipping_details(record)
        #
        #   Early return
        #
        return '' unless record['shipping_details']

        begin
          details = record['shipping_details']['expedited_shipping']

          provider = details['provider']
          service = details['service']

          result = "#{provider} (#{service})"
        rescue
          result = ''
        end

        result
      end




      def record_to_printjob(record)
        p = nil

        begin
          id = record['_id'].to_s

          job = record['job']
          print_request = job['print_request']

          job = add_default_brand_if_required(job)


          p            = PrintJob.new
          p.id         = id
          p.design_id  = print_request['design_id']
          p.output     = "/pdfs/#{id}"
          p.email      = print_request['email']
          p.shipping   = shipping_details(print_request)
          p.created_at = job['created_at']
          p.updated_at = job['updated_at']
          p.status     = job['status']
          #
          #  Unless already set, assume that the brand is Motocal.  This is the safest assumption.
          #
          p.brand      = job['brand']


        rescue => ex
          Logging.error("Caught an exception while building recent_interesting list")

          p = nil
        end

        p
      end



      def build_recent_interesting_list(records)
        result = records.map do |record|
          record_to_printjob(record)
        end

        result.delete_if{|e| e.nil?}

        result.sort_by{|e| e['updated_at']}.reverse
      end

      #
      #   Recent is within X * 24 hours, interesting is not well defined
      #
      def recent_interesting
        time_now = Time.now.to_i

        t_start  = time_now - (86400 * Config.recent_means)

        t_start = Time.at(t_start)

        records = @print_jobs.find({'job.updated_at' => {'$gt' => t_start}},
                                   :fields => ['_id',
                                               'job.print_request.design_id',
                                               'job.print_request.email',
                                               'job.status',
                                               'job.print_request.shipping_details.expedited_shipping',
                                               'job.created_at',
                                               'job.updated_at'])


        build_recent_interesting_list(records)
      end



      def pdf_generation_failed
        find({'job.status' => 'PDF Generation Failed'}).to_a
      end


      def ready_to_generate_pdf
        find({'job.status' => 'Payment Received', 'job.pdf_generated' => { '$exists' => false} }).to_a
      end



      def mark_print_job_pdf_generated(id)
        @print_jobs.update_one({:_id => BSON::ObjectId(id)},
                               '$set' => {
                                 'job.pdf_generated' => Time.now,
                                 'job.updated_at' => Time.now
                               })

        return find_by_id(id)
      end


      def print_jobs_ready_to_email
        find({'job.status' => 'Payment Received', 'job.emailed_customer' => { '$exists' => false} }).to_a
      end


      def mark_print_job_email_sent(id)
        @print_jobs.update_one({:_id => BSON::ObjectId(id)}, '$set' => {'job.emailed_customer' => Time.now,  'job.updated_at' => Time.now})

        return find_by_id(id)
      end


      #
      #   Move job.status ensuring that it was at 'from' and is now at 'to'
      #
      def move_status(id, from, to)
        result = @print_jobs.update_one({
                                          :_id => BSON::ObjectId(id),
                                          'job.status' => from
                                        },
                                        {
                                          '$set' => {
                                            'job.status' => to,
                                            'job.updated_at' => Time.now
                                          }
                                        }
                                       )


        unless result and 1 == result.modified_count
          job = find_by_id(id)

          raise Rocksteady::RS_Inconsistent.new("Storage could not find order #{id}") unless job

          raise Rocksteady::RS_Inconsistent.new("Storage could not update order #{id} in #{job['status']} from #{from} to #{to}")
        end

        return find_by_id(id)
      end



      #
      #   This isn't safe - there's a race condition which could cause two packers to
      #   try to pack the same bin.  This should be implemented in a safer way but
      #   the problem is easy to resolve on the Print Floor and unlikely to happen
      #
      #   NB:  This returns the oldest order which is in the collected state NOT
      #        the order which has been collected the longest
      #
      def oldest_in_collected_state
        result = nil

        records =@print_jobs.find(
          {'job.status' => 'Collected'},
          {:fields => ['id', 'job.created_at']}
        ).sort({'job.created_at' => 1}).to_a


        if records and records.size > 0
          result = records.to_a.first['_id'].to_s
        end

        Rocksteady::Logging.info "Oldest in collected state is #{result}"

        result
      end



      #
      #   Return the container for the job identified
      #
      def container(id)
        result = @print_jobs.find(
          {:_id => BSON::ObjectId(id)},
          {:fields => 'job.print_request.shipping_details.container'}
        )
      end



    end
  end
end
