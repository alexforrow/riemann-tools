module Riemann
  module Tools
    module Process
      require 'rubygems'

      def self.included(base)
        base.instance_eval do
          opt :pid_file, "process id file", :type => String
          opt :pid, "process id", :type => Integer
          opt :nofile_warning, "Open files (% of max) warning threshold", :default => 60
          opt :nofile_critical, "Open files (% of max) critical threshold", :default => 80
          opt :memory_resident_warning, "Resident memory warning threshold (bytes)", :default => 512
          opt :memory_resident_critical, "Resident memory critical threshold (bytes)", :default => 1024
          opt :memory_size_warning, "Total memory warning threshold (bytes)", :default => 1024
          opt :memory_size_critical, "Total memory critical threshold (bytes)", :default => 2048
        end
      end

      def get_pid
        # Process ID can either be specified explicity (take priority) or be read from a pid file
        return options[:pid] if options[:pid]
        return File.read(options[:pid_file]).chomp if options[:pid_file]
        return nil
      end

      def get_process_status
        begin
          return nil unless (pid = get_pid)
        rescue
          return false
        end
        return File.exists?("/proc/#{pid}")
      end

      def report_process(service, tags = Array.new)
        # TODO - add whitelist?

        # Do nothing if we don't have a pid
        begin
          return nil unless (pid = get_pid) 
        rescue Exception => e
          report(
            :service => "#{service} process",
            :state => 'failure',
            :description => "Error getting pid: #{e.message}",
            :tags => tags
          )
        end

        report(
          :service => "#{service} process",
          :state => (get_process_status ? 'ok' : 'failure'),
          #:description => "test description",
          :tags => tags
        )

        # If process is not running there are no metrics to collect
        return false unless get_process_status

        ### nofile metrics ###
        begin
          nofile_current = Dir.entries("/proc/#{pid}/fd").reject{|e| e =~ /^\.{1,2}$/ }.count

          report(
            :service => "#{service} nofile current",
            :metric => nofile_current,
            #:description => "test description",
            :tags => tags
          )
        rescue Exception => e 
          report(
            :service => "#{service} nofile",
            :state => "critical",
            :description => "Error gathering data: #{e.message}",
            :tags => tags
          )
        end

        begin
          unless File.read("/proc/#{pid}/limits") =~ /Max open files\s+(\d+)/
            raise "Unable to parse process limits file"
          end
          nofile_limit = $1

          report(
            :service => "#{service} nofile limit",
            :metric => nofile_limit,
            #:description => "test description",
            :tags => tags
          )
        rescue Exception => e
          report(
            :service => "#{service} nofile limit",
            :state => "critical",
            :description => "Error gathering data: #{e.message}",
            :tags => tags
          )
        end

        ### memory metrics ###
        begin
          size, resident = File.read("/proc/#{pid}/statm").chomp.split(' ')

          report(
            :service => "#{service} memory size",
            :metric => size,
            :tags => tags
          )
          report(
            :service => "#{service} memory resident",
            :metric => resident,
            :tags => tags
          )
        rescue Exception => e
          %w(size resident).each do |type|
            report(
              :service => "#{service} memory #{type}",
              :state => "critical",
              :description => "Error gathering data: #{e.message}",
              :tags => tags
            )
          end
        end

        # TODO - CPU metrics

        return true
      end
    end
  end
end
