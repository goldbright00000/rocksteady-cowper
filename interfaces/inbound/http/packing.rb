require './lib/status_codes'


#
#   Return the next order ready for packing
#
#   It would be easy to argue that this is
#   not RESTful as calling GET again and again
#   will return wildly different objects.
#
#   I don't like the semantics here but it
#   makes it really easy for the UI to build
#   the Packing app.
get '/packing', provides: :json do
  status Rocksteady::Ok


  result = Rocksteady::API::Packing.next_to_pack()

  result = {} unless result


  #
  #  At this point, we either have a valid result or
  #  we threw an error
  #
  JSON.generate result

end



#
#
delete '/packing/:id', provides: :json do
  status Rocksteady::NotFound

  result = {}

  id = params[:id].to_i rescue nil

  Rocksteady::Logging.error "Can't return an order to sorting without an id" unless id

  if id && Rocksteady::API::Packing.return_to_sorting_table(id)
    status Rocksteady::Ok
  end


  JSON.generate result
end






post '/package', provides: :json do
  status Rocksteady::NotFound

  result = {}

  bin_id = params['bin_id'].to_i rescue nil

  packer_name = params['packer_name'] rescue nil

  if Rocksteady::API::Packing.start_packing(packer_name, bin_id)
    status Rocksteady::Ok
  end

  JSON.generate result
end
