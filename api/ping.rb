get '/ping', provides: :json do
  status Rocksteady::Ok

  {
    response: 'pong'
  }
end
