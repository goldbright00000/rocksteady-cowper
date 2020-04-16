require 'bundler'
require 'fog/google'

require '../cowper/config/default'
require '../cowper/lib/logging'

module Rocksteady
  module Storage
    module GCS
      extend self


      @gcs            = nil

      @gcs_project    = Config.google_storage_project
      @gcs_key_file   = Config.google_storage_key_file
      @public_bucket  = Config.google_storage_public_bucket
      @private_bucket = Config.google_storage_private_bucket

      if @gcs_project && @gcs_key_file && @private_bucket && @public_bucket
        @gcs = Fog::Storage::Google.new(google_project: @gcs_project, google_json_key_location: @gcs_key_file)
      else
        Logging.info "Not using GCS as configuration is incomplete. See cowper/storage/google_cloud_services.rb for more."
      end




      def load_object_from_bucket(bucket, path, object_type)
        return false unless @gcs

        gcs_path = path.gsub('/var/cowper/', '')

        result = nil

        begin
          rt = Benchmark.realtime do
            result = @gcs.get_object(bucket, gcs_path).body
          end

          Logging.info "Reading #{object_type} #{gcs_path} from GCS bucket #{bucket} took #{rt}"

        rescue Fog::Errors::NotFound => e
          Logging.error "Fog::Errors::NotFound when reading #{object_type} from GCS bucket gcs://#{bucket}/#{gcs_path}"

        rescue StandardError => e
          Logging.error "StandardError when reading #{object_type} from GCS bucket gcs://#{bucket}/#{gcs_path} because #{e}"
        end


        result
      end



      def load_print_request(path)
        return false unless @gcs

        load_object_from_bucket(@private_bucket, path, 'print request')
      end



      def load_design(path)
        return false unless @gcs

        load_object_from_bucket(@private_bucket, "#{path}/design.json", 'design')
      end




      #
      #   Blocking write to a bucket
      #
      def write_string_to_bucket(bucket, path, string, msg, m_time, options = {})
        return false unless @gcs

        begin
          response = nil

          #
          #   Set some md on the object. The mtime can be used to
          #   sync between local fs and bucket
          #
          options['x-goog-meta-goog-reserved-file-mtime'] = m_time

          actual_time = Benchmark.realtime do
            response = @gcs.put_object(bucket, path, string, options)
          end

          Logging.error "Saving #{msg} to gcs did not return 200 as expected for gcs://#{bucket}/#{path}" unless response and response.status == 200

          Logging.info "Saving #{msg} #{path} to GCS bucket #{bucket} actually took #{actual_time}"

        rescue StandardError => e
          Logging.error "Unable to write_string_to_bucket for #{msg} to GCS path #{bucket}/#{path} because #{e}"
        end

      end




      #
      #  Optional blocking write to a bucket.
      #
      def save_file_to_bucket(path, string, msg, bucket, m_time, block)
        return false unless @gcs

        begin
          apparent_time = Benchmark.realtime do

            if block
              Logging.info "Blocking write for #{msg} for #{path} to #{bucket}"
              write_string_to_bucket(bucket, path, string, msg, m_time)
            else
              Thread.new do
                Logging.info "NON Blocking write for #{msg} for #{path} to #{bucket}"
                write_string_to_bucket(bucket, path, string, msg, m_time)
              end
            end

          end

          Logging.info "Saving #{msg} #{path} to GCS bucket #{bucket} appeared to take #{apparent_time}"

        rescue StandardError => e
          Logging.error "Unable to save #{path} to GCS bucket #{bucket} because #{e}"
        end

      end




      #
      #   We bind save_file_to_bucket to the private Cowper bucket
      #
      def save_file_to_public_bucket(path, string, msg, m_time, block = false)
        return false unless @gcs

        save_file_to_bucket(path, string, msg, @public_bucket, m_time, block)
      end



      #
      #   We bind save_file_to_bucket to the private Cowper bucket
      #   For new Designs, we really want to block on the write to
      #   the bucket otherwise a quick GET for the Design may hit
      #   a server without a local copy and before the bucket gets
      #   updated.  This does not guarantee that the bucket will
      #   have the file as it is 'eventually' consistent but it
      #   really helps.  If proven wrong on this, we can set the
      #   session affinity in the load balancer to push the client
      #   back to the same server.
      #
      def save_file_to_private_bucket(path, string, msg, m_time, block = false)
        return false unless @gcs

        save_file_to_bucket(path, string, msg, @private_bucket, m_time, block)
      end



      #
      #   Strip off the '/var/cowper' bit and save to GCS
      #
      def save_design(path, string, m_time, block = false)
        return false unless @gcs

        path = path.gsub('/var/cowper/', '')

        save_file_to_private_bucket("#{path}/design.json", string, "design", m_time, block)
      end



      #
      #   Strip off the '/var/cowper' bit and save to GCS
      #
      def save_print_request(path, string)
        return unless @gcs

        gcs_path = path.gsub('/var/cowper/', '')

        save_file_to_private_bucket("#{gcs_path}/shapes.js", string, Time.now.to_i, 'print request', block = true)
      end



      #
      #   This will fail if the local file is missing.
      #   Strip off the '/var/cowper' bit and save to GCS
      #
      def copy_selector(dir)
        return unless @gcs

        local_filename = "#{dir}/selector.png"

        gcs_path = local_filename.gsub('/var/cowper/', '')

        save_file_to_public_bucket(gcs_path, File.read(local_filename), Time.now.to_i, 'selector')
      end



      #
      #   This will fail if the local file is missing.
      #   One use for this is to copy the invoice
      #   files to a public bucket
      #
      def copy_dir_to_public_gcs(local_dir)
        return unless @gcs

        remote_path = local_dir.gsub('/var/cowper/', '')

        gsutil = Rocksteady::Config.gsutil

        s = "#{gsutil} -m cp -r #{local_dir} gs://#{@public_bucket}/#{remote_path}"

        begin
          `#{s}`
        rescue StandardError => e
          Logging.error "Could not copy #{local_dir} because #{e}"
        end
      end
    end
  end
end
