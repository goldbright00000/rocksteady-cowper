#
#   Called when someone swipes a decal
#
post '/collections', provides: :json do
  status Rocksteady::Ok

  type, position, printjob_id = params['qron_data'].split('|') rescue [nil, nil, nil]

  collector = params['collector_name']

  bin = Rocksteady::API::Collections.collect_decal(collector, type, position, printjob_id)

  JSON.generate bin
end




get '/collections', provides: :json do
  bins = Rocksteady::API::Collections.list_bins

  JSON.generate bins
end




get '/collections/:id', provides: :json do
  status Rocksteady::NotFound

  result = {}

  id = params['id'].to_i rescue nil

  result = Rocksteady::API::Collections.get_collection_status(id)

  if result
    status Rocksteady::Ok
  end

  JSON.generate result.to_h
end
