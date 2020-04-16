require './model/notification'

module Rocksteady::API::Library
  extend self

  def add(params)
    Rocksteady::Notification.add_to_library(params)
  end

end
