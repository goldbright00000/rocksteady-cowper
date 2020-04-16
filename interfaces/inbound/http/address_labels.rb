post '/address_labels', provides: :json do
  status Rocksteady::NotFound

  container = params['container']
  job_id    = params['job_id']

  Rocksteady::Logging.info("Got a label request for #{job_id} in #{container}")

  result = {}

  job = Rocksteady::Storage::Orders.find_by_id(job_id)

  if job
    status Rocksteady::Ok

    result = Rocksteady::API::AddressLabels.generate(job, container)
  end

  JSON.generate result
end
