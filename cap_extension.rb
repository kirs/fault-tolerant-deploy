require 'thread'
require 'sshkit'
require 'mutex_m'

class ShopifyRunner < SSHKit::Runner::Abstract
  module FailedHosts
    extend Mutex_m
    extend self

    def push(host)
      instance << host
      on_new_host(host)
    end

    def include?(host)
      instance.include?(host)
    end

    def instance
      mu_synchronize do
        @instance ||= Set.new
      end
    end

    def on_new_host(host)
      # drop it
    end
  end

  def execute
    threads = []
    hosts.each do |host|
      threads << Thread.new(host) do |h|
        if FailedHosts.include?(h)
          puts "ignoring #{h}"
        else
          begin
            backend(h, &block).run
          rescue StandardError, Errno::ETIMEDOUT, Net::SSH::ConnectionTimeout => e
            b = SSHKit.config.backend.new(h)
            b.error "Exception while executing #{host.user ? "as #{host.user}@" : "on host "}#{host}: #{e.message}"
            FailedHosts.push(h)
          end
        end
      end
    end
    threads.map(&:join)
  end
end

SSHKit.config.default_runner = ShopifyRunner
