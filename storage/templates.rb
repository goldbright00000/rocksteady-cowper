module Rocksteady
  module Storage
    extend self

    @templates = Storage.db.collection('templates')

    def find_template(id)
      raise "You must provide an id" unless valid_mongo_id?(id)

      @templates.find('_id' => id).first
    end


    def save_template(id, doc)
      raise "You must provide an id" unless valid_mongo_id?(id)

      @templates.insert({'_id' => id, 'template' => doc} )
    end
  end
end
