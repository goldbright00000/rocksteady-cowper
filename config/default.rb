require 'pp'

require '../cowper/lib/logging'
require '../cowper/lib/exception_handler'


module Rocksteady
  module Config
    extend self

    LOCAL_OVERRIDES_FILE = '/var/hg/repos/cowper/config/local_overrides.txt'

    @config = {
      nginx_url: 'https://127.0.0.1',

      #
      #   HTTP Basic Auth settings
      #
      basic_auth_user:     'rockSteady',
      basic_auth_password: 'Simpsons',
      mandrill_key:        '',
      recent_means:        7,
      url_hostname:        `hostname -f`.strip,
      show_debug_msgs:     false,
      ssh_config_path:     '~/.ssh/config',
      send_notifications:  true,
      lsd_user:            'chris@rocksteady.com',
      cowper_dir:          '/var/cowper',
      google_storage_project: nil,
      google_storage_key_file: nil,
      google_storage_public_bucket: nil,
      google_storage_private_bucket: nil,
      google_storage_social_bucket: nil,
      redis_password:      nil,
      container_url:       'https://127.0.0.1/api/containers',
      s3_print_bucket: 'public-motocal-production-cowper',
      address_label_dir: '/var/hg/repos/dundrum/public/address_labels',
      brand: 'Motocal',
      sub_brand: '',
      facebook_page: 'https://www.facebook.com/Motocal',
      gsutil: '/snap/bin/gsutil',
    }


    def method_missing(meth, *args, &block)

      super unless @config.keys.include? meth

      _return = @config[meth]
    end



    def load_local_overrides
      return unless File.exists?(LOCAL_OVERRIDES_FILE)

      s = File.read(LOCAL_OVERRIDES_FILE)

      begin
        x = self.instance_eval("\{#{s}\}")

        Rocksteady::Logging.info "Adding local overrides from #{LOCAL_OVERRIDES_FILE}\n\t" + x.pretty_inspect.gsub(':', "\n\t:").gsub(/:|{|}/,'').gsub('=>', ': ') + "\n"

        @config.merge! x

      rescue Exception => ex
        Rocksteady::Logging.error "There was an error loading your local overrides #{ex}"
      end

      Rocksteady::Logging.show_debug_msgs = @config[:show_debug_msgs]
    end



    def private_dir
      "#{@config[:cowper_dir]}/private"
    end


    def public_dir
      "#{@config[:cowper_dir]}/public"
    end

  end



  Config.load_local_overrides

end
