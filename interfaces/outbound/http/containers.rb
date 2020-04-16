module Rocksteady
  module Containers
    extend self

    public

    #
    #   This method interfaces with Dawson to get a list of containers which could be used to hold
    #   the customers order.  The list is ordered with the prefered container first.
    #   If Dawson can't be contacted, we return "['Z']" to indicate that the largest box should be
    #   used.
    #
    def suggest_containers_for_job(job)
      job_id = job['_id']

      raise RS_Inconsistent.new("The print_request is not valid for #{job_id}") unless job['print_request']
      raise RS_Inconsistent.new("The client did not provide shapes for #{job_id}") unless job['print_request']['shapes']

      shapes = Rocksteady::Services::Shapes.shapes_from_job(job)

      result = ['Z']

      msg = HTTParty.get(Config.container_url, :query => Rack::Utils.build_nested_query(shapes: shapes)) rescue nil

      if msg && "200" == msg.response.code

        h = JSON.parse(msg.response.body)

        result = h.collect {|e| e['name']}

      else
        Logging.error("The call to /api/containers threw an exception")
      end


      result
    end

  end
end
