#
#   This class implements a persistent Bin allocator on Redis
#
#   There are two important indexes:
#      REDIS_BINS_STORE maps a bin to the print_job in it
#      REDIS_JOBS_STORE maps a job to the bin it is in
#
#      Together these let us figure everything we need to
#      know about the state of the bins.
#
#   When a new job is created, we need to know where it can
#   be stored. In most cases it will be stored in an existing
#   free bin. In this case we just pop a bin_id from the
#   REDS_FREE_BINS collection.  In some cases, all existing
#   bins will be free so we need to create a new one by
#   incrementing the REDIS_NEXT_BIN_ID. This is the high
#   watermark for bin ids.
#
#
require './storage/interface'
require 'json'
require './model/bins'
require 'redis'


module Rocksteady
  module BinManager
    extend self

    #
    #  c.c.b.store maps bins to print job ids
    #  c.c.j.store maps job ids to bins
    #  c.c.b.next is the id of the bin to assign if
    #    c.c.b.free is empty
    #  c.c.b.free is a list of bins which were in use
    #  but have now been emptied (order shipped)
    #
    REDIS_BINS_STORE  = 'cowper.collection.bins.store'
    REDIS_JOBS_STORE  = 'cowper.collection.jobs.store'
    REDIS_NEXT_BIN_ID = 'cowper.collection.bins.next'
    REDIS_FREE_BINS   = 'cowper.collection.bins.free'


    @script_num_bins  = <<-SCRIPT.gsub(/^ {4}/,'')

    SCRIPT


    #
    #   A script to find the next available bin
    #   We try to get a bin from the free list
    #   but if that's empty then we allocate a new
    #   one (and someone runs over to Dunnes)
    #
    @script_next_free = <<-SCRIPT.gsub(/^ {4}/,'')

    local free = ''
    local next = '#{REDIS_NEXT_BIN_ID}'

    local result = redis.call('LPOP', '#{REDIS_FREE_BINS}')

    if result == false then
       result = redis.call('INCR', next)
    end

    return result
    SCRIPT


    #
    #   Get the status of all bins i.e. which job is in
    #   which bin
    #
    @script_all_bins = <<-SCRIPT.gsub(/^ {4}/,'')
    local next = redis.call('GET', '#{REDIS_NEXT_BIN_ID}')

    if not next then return {} end

    local result = {}
    for idx = 0, next, 1 do
       result[idx] = redis.call('GET', '#{REDIS_BINS_STORE}:'..idx)
    end

    return result
    SCRIPT


    #
    #   Thus script empties a bin by deleting the association
    #   between the bin store and the job store then adding
    #   the bin to the list of free bins
    #
    @script_empty_bin = <<-SCRIPT.gsub(/^ {4}/,'')

    local bin_id = ARGV[1]
    local job_id = ARGV[2]

    redis.call('DEL', '#{REDIS_BINS_STORE}:'..bin_id)
    redis.call('DEL', '#{REDIS_JOBS_STORE}:'..job_id)
    redis.call('LPUSH','#{REDIS_FREE_BINS}', bin_id)

    SCRIPT




    @redis = Rocksteady::Storage.try_connection('Redis') {
      _return = Redis.new(:password => Config.redis_password)

      _return.ping

      _return
    }


    @sha1_next_free = @redis.script(:load, @script_next_free)
    @sha1_all_bins  = @redis.script(:load, @script_all_bins)
    @sha1_empty_bin = @redis.script(:load, @script_empty_bin)











    #
    #   Get a free bin or allocate a
    #   completely new one.  In the real
    #   world someone nips out to Dunnes
    #   or IKEA.
    #
    def next_free_bin
      @redis.evalsha(@sha1_next_free).to_i
    end



    def find_by_printjob_id(job_id)
      bin_id = @redis.get(job_store_key(job_id))

      if bin_id
        bin_id = bin_id.to_i

        json = @redis.get(bin_store_key(bin_id))

        h = JSON.parse(json, symbolize_names: true)

        _return = Bin.new(h[:id], h[:print_job_id], h[:to_collect], h[:num_collected])
      end

      _return
    end



    #
    #   As decals are taken from the sorting table, they are scanned and assigned to bins.
    #   Each decal has a QR code which gives its position and pj_id.
    #
    def add_to_bin(printjob_id, position)
      raise RS_NotFound("PrintJob #{printjob_id} does not exist") unless Rocksteady::Storage::Orders.exists?(printjob_id)

      Rocksteady::Logging.info "Adding '#{position}' from order #{printjob_id} to a bin"

      to_collect = Rocksteady::Storage::Orders.decals_purchased(printjob_id)

      bin = find_by_printjob_id(printjob_id)

      #
      #  If this is the first decal collected for a pj, it will not have a bin yet.
      #
      unless bin
        bin = Rocksteady::Bin.new(next_free_bin, printjob_id, to_collect)

        Rocksteady::Logging.info "Allocating new bin #{bin.id} to #{printjob_id} and moving order to collecting."

        Rocksteady::Orders.update_status(printjob_id, 'Collecting')
      end

      bin = bin.add(position)

      save bin

      Rocksteady::Logging.info "Bin #{bin.id} now contains #{printjob_id}."

      return bin
    end


    #
    #   Generate the key for a bin
    #
    def bin_store_key(bin_id)
      "#{REDIS_BINS_STORE}:#{bin_id}"
    end


    #
    #   Generate the key for a job
    #   Used to reverse index job => bin
    #
    def job_store_key(job_id)
      "#{REDIS_JOBS_STORE}:#{job_id}"
    end



    #
    #   Persist the bin, storing the JSON for the Job against
    #   the id of the bin
    #
    def save(bin)
      #
      #   index bin => job
      #
      @redis.set(bin_store_key(bin.id), JSON.generate(bin))
      #
      #   Reverse index job => bin
      #
      @redis.set(job_store_key(bin.print_job_id), bin.id)
    end



    def all
      _return = @redis.evalsha(@sha1_all_bins)

      _return = _return.map do |e|
        if e
          JSON.parse(e, symbolize_names: true)
        else
          {}
        end
      end

      _return.select!{|e| e && e != {}}

      _return = [] unless _return

      _return
    end



    #
    #  Called when an order is packed
    #
    def empty_bin(bin)
      Rocksteady::Logging.info "Emptying bin #{bin.id} for order #bin{bin.print_job_id}"

      _return = @redis.evalsha(@sha1_empty_bin, [], [bin.id, bin.print_job_id])
    end




    def find_by_id(id)
      _return = nil

      s = @redis.get(bin_store_key(id)) rescue "{}"

      if s
        h = JSON.parse(s, symbolize_names: true)

        _return = Bin.new(h[:id], h[:print_job_id], h[:to_collect], h[:num_collected])
      end

      _return
    end





    def next_to_pack()
      _return = nil

      id = Storage::Orders.oldest_in_collected_state

      if id
        _return = find_by_printjob_id(id)

        raise RS_Inconsistent.new("Order #{id} is not in any bin") unless _return

        Storage::Orders.move_status(_return.print_job_id, 'Collected', 'Packing')
      end

      _return
    end
  end
end
