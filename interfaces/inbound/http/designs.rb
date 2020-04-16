#
#   The HTTP entry point for designs (aka order_kits)
#

#
#   This is the most important method here, it's what
#   actually gets called by a client when they want to
#   build a kit.
#
post %r{/order_kits} do
  result = {}

  status Rocksteady::InternalError

  content_type :json

  #
  #   Both of these are set by NGINX but only
  #   likely to be valid in production
  #
  params['geo_location'] = request.env['HTTP_X_GEO']
  params['client_ip']    = request.env['HTTP_X_FORWARDED_FOR']
  params['sub_brand']    = Rocksteady::Config.sub_brand

  design = Rocksteady::API::Design.create(params)

  if design
    status Rocksteady::Created

    result = design

  end

  result = {} unless result

  result.to_json
end





get '/order_kits/:id' do
  status Rocksteady::NotFound

  content_type :json

  #
  #   This is always a string on the way back out
  #
  result = Rocksteady::API::Design.find_by_id(params[:id])

  status(Rocksteady::Ok) if result

  result
end




put '/order_kits/:id' do
  content_type :json

  code = Rocksteady::NotFound

  id = params['id']
  design = nil

  begin
    s = request.body.read

    design = JSON.parse s

    code = Rocksteady::API::Design.update(id, design)

  rescue Exception => ex
    Rocksteady::Logging.error "Exception in put /order_kits/id #{ex}"
  end


  status(code)
end





get '/admin', provides: :html do
  status Rocksteady::Ok

  @print_queue = Rocksteady::Orders.recent_interesting

  haml :'/kits/list'
end



get '/designs/:id', provides: :json do
  status Rocksteady::Ok

  id = params['id']

  _return = Rocksteady::API::Design.find_by_id(id)

  unless _return
    status Rocksteady::NotFound

    _return = '{status: \'404 : Not Found\'}'
  end

  _return
end
