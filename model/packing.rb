require './lib/status_codes'

module Rocksteady
  module Packing
    extend self


    def check_params(collector, bin_id)
      raise RS_BadParams.new('The collector name is missing') unless collector

      bin = Rocksteady::BinManager.find_by_id(bin_id)

      raise RS_NotFound.new("The bin #{bin_id} does not exist") unless bin

      raise RS_BadParams.new("The order has not started packing yet") unless bin.packing?

      return bin
    end
  end
end
