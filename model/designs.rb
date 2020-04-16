require 'forwardable'
require 'tempfile'
require 'erb'

require './storage/interface'
require './lib/network'
require './lib/status_codes'



module Rocksteady

  module Designs
    extend Forwardable
    extend self

    def_delegators Rocksteady::Storage::Designs, :find_by_id, :save, :recent_interesting, :ready_to_email, :mark_email_as_sent


    def create(params, design)
      Rocksteady::Storage::Designs.save(params, design)
    end




    def all_fields_present(record)
      keys = ["order_kit", "attributes", "features", "components", "positions", "shapes", "decals", "graphics", "manufacturers"] - record.keys

      return keys == []
    end




    def update(id, design)
      #
      #   NotProcessable as the syntax is valid so BadRequest
      #   is not appropriate
      #
      return NotProcessable unless all_fields_present(design)

      record = Storage::Designs.find_metadata_by_id(id)

      return NotFound unless record

      #
      #  Ember puts the email address in a non-obvious place so I
      #  copy it back to the standard 'order_kit'
      #
      design['email'] = design['users'][0]['email'] rescue nil

      Rocksteady::Storage::Designs.update(record, design)

      Rocksteady::Notification.design_update design

      return NoContent
    end





  end
end
