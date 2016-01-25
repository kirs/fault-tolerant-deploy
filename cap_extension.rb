require 'thread'
require 'sshkit'
require 'mutex_m'

class ShopifyRunner < SSHKit::Runner::Abstract
  class FailedHosts
    extend Mutex_m
    class << self
      def push(host)
        instance.push(host)
      end
      def include?(host)
        instance.include?(host)
      end

      def instance
        mu_synchronize do
          @instance ||= new
        end
      end
    end

    def initialize
      @list = Set.new
      @m = Mutex.new
    end

    def on_new_host(host)
      # drop it
    end

    def push(hostname)
      @m.synchronize do
        @list << hostname
        on_new_host(hostname)
      end
    end

    def include?(hostname)
      @list.include?(hostname)
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
