module Riemann
  module Tools
    module Http
      require 'rubygems'
      require 'net/http'
      require 'uri'

      def self.included(base)
        base.instance_eval do
          opt :http_healthcheck_url, "URL to perform http healthcheck against", :type => String
          opt :http_healthcheck_timeout, "Open and read timeout on http healthcheck (seconds)", :default => 2.0, :type => Float
        end
      end

      def report_http_healthcheck(service, tags = Array.new)
        return nil unless opts[:http_healthcheck_url]
        
        uri = URI.parse(opts[:http_healthcheck_url].to_s)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true if uri.scheme == 'https'
        http.open_timeout = opts[:http_healthcheck_timeout]
        http.read_timeout = opts[:http_healthcheck_timeout]

        begin
          response = http.get(uri.request_uri)

          report(
            :service => "#{service} http_healthcheck",
            :state => (response.code =~ /^2..$/ ? 'ok' : 'failure'),
            :description => "#{response.code} #{response.msg}",
            :tags => tags
          )
        rescue Timeout::Error
          report(
            :service => "#{service} http_healthcheck",
            :state => 'failure',
            :description => "Timeout after #{opts[:http_healthcheck_timeout]} seconds",
            :tags => tags
          )
        end
      end
    end
  end
end
