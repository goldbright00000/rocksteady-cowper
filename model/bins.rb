require './config/default'
require './model/bin_manager'

module Rocksteady
  class Bin
    private


    public
    attr_reader :id, :print_job_id, :collected, :to_collect, :created_on


    def initialize(id, print_job_id, to_collect, num_collected = 0)
      @id = id

      @print_job_id = print_job_id

      @to_collect = to_collect

      @num_collected = num_collected

      @num_remaining = @to_collect.map.inject(0) {|count, decal| count + decal[:qty_remaining_to_collect]}

      @status = 'Collecting'

      @created_on = Time.now.to_i
    end



    def to_h
      h = {}

      self.instance_variables.each do |v|
        #
        #   We want 'name' not '@name' as the JSON name
        #
        json_name = v[0] == '@' ? v[1..-1] : v

        h[json_name] = self.instance_variable_get v
      end

      h['status'] = self.status

      h
    end




    def to_json(*a)
      to_h.to_json(*a)
    end




    def add(position)
      entry = @to_collect.find{|c| c[:name] == position}

      if entry[:qty_remaining_to_collect] > 0
        entry[:qty_remaining_to_collect] = entry[:qty_remaining_to_collect] - 1

        Rocksteady::Logging.info("Collected '#{position}' for #{@print_job_id}")

        @num_collected += 1
        @num_remaining -= 1

        if 0 == @num_remaining
          Rocksteady::Logging.info("Fully collected #{@print_job_id}")

          @status = 'Collected'

          Rocksteady::Orders.mark_as_collected(@print_job_id)
        end
      end

      self
    end



    def status
      Rocksteady::Orders.status(@print_job_id)
    end


    def packing?
      "Packing" == self.status
    end

    def collected?
      "Collected" == self.status
    end
  end
end
