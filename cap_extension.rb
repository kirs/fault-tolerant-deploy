require 'thread'
require 'sshkit'
require 'mutex_m'

class FailedHosts
  def initialize
    @hosts = Set.new
  end

  attr_reader :hosts

  def push(host)
    max_servers_to_fail = 2
    if @hosts.size > max_servers_to_fail
      # PROBLEM: Capistrano::Configuration.servers is private here
      # which we need to calculate failure_tolerance 0.05
      return false
    end

    @hosts << host
    on_new_host(host)
    true
  end

  def include?(host)
    @hosts.include?(host)
  end

  def on_new_host(host)
    # drop it
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
          options[:failed_hosts].push(h)
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
    @failed_hosts = FailedHosts.new
    hosts = hosts - @failed_hosts.hosts.to_a

    options[:failed_hosts] = @failed_hosts
    super(hosts, options, &block)
  end
end

self.extend MyDSL
