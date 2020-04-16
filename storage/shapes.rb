module Rocksteady
  module Storage
    module Shapes
      extend self



      def write_to_local_fs(private_path, json_filename, json)
        FileUtils.mkdir_p(private_path)

        bytes_written = IO.write(json_filename, json.to_s)

        bytes_to_write = json.bytesize

        raise "The print_job could not be updated because not all bytes were written (#{bytes_written} v #{bytes_to_write})" unless bytes_written == bytes_to_write
      end



      def write_to_gcs(json_filename, json)
        GCS.save_print_request(json_filename, json)
      end


      def write_to_storage(id, doc)
        shapes = doc['print_request']['shapes'] rescue nil

        raise "The print job could not be updated because one or more of shapes or id was missing" unless id && shapes

        private_path = Storage::Orders.private_storage_path(id)

        string = JSON.pretty_generate({'shapes' => shapes})

        filename = "#{private_path}/shapes.js"

        write_to_local_fs(private_path, filename, string)

        write_to_gcs(private_path, string)


        doc['print_request'].delete('shapes')
        doc['print_request']['shape_storage'] = filename
      end




      def read_from_storage(json)
        storage_dir = json['job']['print_request']['shape_storage']

        string = nil
        string = GCS.load_print_request(storage_dir)
        string = File.read(storage_dir) unless string

        shapes = JSON.parse(string)
      end



      def find(id)
        Storage::MySQL.find_by_id_or_name('shapes', id)
      end



      def find_by_id(ids, fields = ['*'])
        ids = [ids] unless Array == ids.class

        field_names = fields.map{|f| f.to_s}.join(',')
        shape_ids  = ids.map{|s| "'#{s}'"}.join(',')

        sql = "select #{field_names} from shapes where id in (#{shape_ids}) order by id asc"

        return Storage::MySQL.fetch(sql)
      end
    end
  end
end
