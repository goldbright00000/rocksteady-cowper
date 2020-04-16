#!/usr/bin/env ruby

require 'bundler'
require 'sinatra'
require 'slogger'
require 'haml'
require 'json'
require 'awesome_print'
require 'fog/google'

require './lib/reloader' if File.exists?('./lib/reloader.rb')

require './model/designs'
require './model/orders'
require './model/payments/upg'
require './model/address_label'
require './model/bins'
require './model/packing'
require './model/notification'

require './lib/status_codes'
require './lib/logging'
require './lib/compressedrequests'
require './lib/exception_handler'

require './config/default'

require './api/collections'
require './api/designs'
require './api/packing'
require './api/orders'
require './api/upg'
require './api/address_labels'
require './api/library'
require './api/ping'

require './interfaces/inbound/http/designs'
require './interfaces/inbound/http/collections'
require './interfaces/inbound/http/packing'
require './interfaces/inbound/http/address_labels'
require './interfaces/inbound/http/orders'
require './interfaces/inbound/http/library'


require './interfaces/outbound/http/rs_server'
require './interfaces/outbound/http/shapes'
require './interfaces/outbound/http/address_labels'
require './interfaces/outbound/http/containers'






# Don't log them. We'll do that ourself
set :dump_errors, false

#  Must be false for error...do to trap errors
set :raise_errors, false

# Disable internal middleware for presenting errors
# as useful HTML pages
set :show_exceptions, false


use CompressedRequests

set :lock, true


error do
  ex = env['sinatra.error']

  code, _return = Rocksteady::ExceptionHandler.handle_error(ex)

  status code

  _return
end
