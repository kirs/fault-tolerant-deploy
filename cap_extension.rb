require 'thread'
require 'sshkit'
require 'mutex_m'

class FailedHosts
  def initialize
    @hosts = Set.new
  end

  attr_reader :hosts

  def push(host)
    if @hosts.size >= max_servers_to_fail
      return false
    end

    @hosts << host
    on_new_host(host)
    true
  end

  def include?(host)
    @hosts.include?(host)
  end

  private

  def on_new_host(host)
    # drop it
  end

  def max_servers_to_fail
    total_servers = Capistrano::Configuration.env.send(:servers).to_a.size
    (fetch(:failure_tolerance, 0) * total_servers).ceil
  end
end

class ShopifyRunner < SSHKit::Runner::Abstract
  def execute
    threads = []
    hosts.each do |host|
      threads << Thread.new(host) do |h|
        begin
          backend(h, &block).run
        rescue StandardError, Errno::ETIMEDOUT, Net::SSH::ConnectionTimeout => e
          b = SSHKit.config.backend.new(h)
          b.error "Exception while executing #{host.user ? "as #{host.user}@" : "on host "}#{host}: #{e.message}"

          # returns false if there are too many failed servers
          # raise back
          unless options[:failed_hosts].push(h)
            raise
          end
        end
      end
    end
    threads.map(&:join)
  end
end

SSHKit.config.default_runner = ShopifyRunner

module MyDSL
  def on(hosts, options={}, &block)
    # exclude failed hosts
    @failed_hosts ||= FailedHosts.new
    hosts = hosts - @failed_hosts.hosts.to_a
    options[:failed_hosts] = @failed_hosts
    super(hosts, options, &block)
  end
end

self.extend MyDSL
