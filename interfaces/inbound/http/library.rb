post '/library_entry', provides: :json do
  status Rocksteady::Accepted

  request.body.rewind

  Rocksteady::API::Library.add request.body.read

  return ''
end
