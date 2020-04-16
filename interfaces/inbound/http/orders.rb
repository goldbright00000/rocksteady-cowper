require 'byebug'

get %r{/print_requests/(.{20,25}).html}, provides: :html do
  status Rocksteady::NotFound

  @print_id = params['captures'][0] rescue nil

  @job = Rocksteady::API::Orders.find_by_id(@print_id)

  @current_container = @job['print_request']['shipping_details']['container']

  #
  # If we have already packed this one, then a container will have
  # been selected otherwise we suggest one now.
  #
  unless @current_container
    @containers = Rocksteady::Containers.suggest_containers_for_job(@job)

    @current_container = @containers[0]['name'] rescue 'Unknown'
  end

  if @job
    status Rocksteady::Ok
  end


  @qrcode = "https://#{request.env['HTTP_HOST']}/api/print_requests/#{@print_id}.html"

  haml :'/jobs/show'

end




get '/print_requests', provides: :json do
  all = Rocksteady::API::Orders.recent_interesting

  all.to_json
end




get %r{/print_requests/(.{20,25})}, provides: :json do
  print_id = params['captures'][0] rescue {}

  job = Rocksteady::API::Orders.find_by_id(print_id)

  job['print_request'].delete('shape_storage') rescue nil

  job.to_json rescue '{}'
end




#
#   Accept or reject a print job.
#
#   The job references a Design which must:
#
#   be conformant to the spec (all required fields present) otherwise reject with 422
#
#   contain a desing_id present in the Designs collection otherwise the job is refused with 403
#
#
post '/print_requests', provides: :json do
  status Rocksteady::Forbidden

  content_type :json

  string = request.body.read

  json = JSON.parse(string)

  begin
    id, job = Rocksteady::API::Orders.new(json)

    response.headers['Location'] = "/api/print_requests/#{id}"

    upg_transaction_id = "#{job['created_at'].to_i}#{rand(10 ** 10).to_s.rjust(10,'0')}"

    msg = {
      :print_request => {
        :id => "#{id}",
        :UPGTransactionId => upg_transaction_id
      }
    }


    Rocksteady::Logging.info "Returning new PrintRequest id #{id} for UPG transaction #{upg_transaction_id}"
    #
    #   This is the end of the normal path, we create the request
    #
    status Rocksteady::Created

  rescue Rocksteady::RS_Error => ex
    status(ex.code)

    msg = {
      :print_request => {:reason => ex.to_s}
    }

  rescue RuntimeError => ex
    msg = {
      :print_request => {:reason => ex.to_s}
    }

    status
  end

  JSON.generate(msg)
end





#
#   Accept or reject a print job.
#
#   The job references a Design which must:
#
#   be conformant to the spec (all required fields present) otherwise reject with 422
#
#   contain a desing_id present in the Designs collection otherwise the job is refused with 403
#
#
put %r{/print_requests/(.{20,25})}, provides: :json do
  status Rocksteady::Forbidden

  job_id = params['captures'][0]

  content_type :json

  print_request = request.body.read

  job = JSON.parse(print_request)

  begin
    job = Rocksteady::Orders.update(job_id, job)

    Rocksteady::Logging::info "Got an update to print_request #{job_id}"
    #
    #   This is the end of the normal path, we create the request
    #
    status Rocksteady::Ok

    Rocksteady::Notification.new_print_request print_request

  rescue Rocksteady::RS_Error => ex
    status(ex.code)

    msg = {
      :print_request => {:reason => ex.to_s}
    }

  rescue RuntimeError => ex
    msg = {
      :print_request => {:reason => ex.to_s}
    }

    status
  end

  ''
end
