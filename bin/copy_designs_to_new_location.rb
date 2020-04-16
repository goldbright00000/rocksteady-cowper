#!/usr/bin/env ruby
#
#
require "./storage/interface"
require 'byebug'
require 'getoptlong'



module Rocksteady

  module Utils
    module CopyDesigns
      extend self


      def help
        puts "
        Help

        Copy tests from srvr2.  Works via a copy of the MongoDB
        If your local copy is out of sync with the production
        version then things won't work as expected.

        The main options are
        --------------------
        --since       Run tests from this one
        --local       Copy files from /var/cowper to /mnt/cowper
        --production  Copy files from srvr2 to /var/cowper

        Optional
        --------
        --help     Display this help text
    "

      end



      def since_to_ts(arg)
        begin
          to_ts = {'min' => 60, 'mins' => 60,
                 'hour' => 3600, 'hours' => 3600,
                 'day' => 86400, 'days' => 86400,
                 'week' => 604800, 'weeks' => 604800}

          parts = arg.split('.')

          qty = parts[0].to_i

          units = parts[1]

          ts = Time.now.to_i - (qty * to_ts[units])

        rescue => e
          puts "Could not process the --since argument #{arg}"
        end


        return ts
      end


      def get_options
        ts     = nil
        source = nil
        flags  = []

        opts = GetoptLong.new(
          [ '--help',       '-?',   GetoptLong::NO_ARGUMENT ],
          [ '--since',      '-s',   GetoptLong::REQUIRED_ARGUMENT ],
          [ '--production', '-p',   GetoptLong::NO_ARGUMENT ],
          [ '--gcs',        '-g',   GetoptLong::NO_ARGUMENT ],
          [ '--local',      '-l',   GetoptLong::NO_ARGUMENT ],
          [ '--dryrun',     '-d',   GetoptLong::NO_ARGUMENT ],
        )

        opts.each do |opt, arg|
          case opt
          when '--since'
            ts = since_to_ts(arg)

          when '--local'
            source = :local

          when '--production'
            source = :production

          when '--dryrun'
            flags += [:dry_run]

          when '--help'
            help
            exit 0
          end
        end

        return ts, source, flags
      end




      def rsync(src, dst, flags)
        `mkdir -p #{dst}`

        switches = '-azh --stats'
        switches << ' --dry-run' if flags.include?(:dry_run)

        command = "rsync #{switches} #{src} #{dst}"

        puts "Running: #{command}"

        puts `#{command}`

        puts "Rsync failed!" && exit(1) if 0 != $?.exitstatus && false

      end



      def copy_from_local(id, flags)
        src_path = Rocksteady::Storage::Designs.private_storage_path(id)
        dst_path = src_path.gsub('/var/cowper', '/mnt/cowper')

        rsync "#{src_path}/", dst_path[0..-24], flags
      end



      def copy_from_production(id, flags)
        src_path = Rocksteady::Storage::Designs.private_storage_path(id)
        dst_path = src_path

        rsync "srvr2:/#{src_path}/*", dst_path, flags
      end



      def copy_from(src, design, flags)
        case src
        when :local
          copy_from_local design.id, flags

        when :production
          copy_from_production design.id, flags

        else
          puts "Don't know how to copy from #{src}"
        end
      end



      def copy(source, designs, flags)
        size = designs.size

        count = 0

        designs.each do |design|
          id = design.id

          count += 1

          puts "\n\nDesign #{count} of #{size}"


          copy_from source, design, flags
        end
      end



      def complain_and_exit
        puts "You must specify --since and one of --local or --production"
        exit
      end


      def run
        since, source, flags = get_options

        complain_and_exit unless since && source

        puts "Running for items modified since  #{Time.at since}"

        designs = Rocksteady::Storage::Designs.updated_since(since)

        puts "#{designs.size} files to copy"

        copy source, designs, flags
      end
    end
  end

end


Rocksteady::Utils::CopyDesigns.run()
