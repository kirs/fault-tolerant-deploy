require 'thread'
require 'sshkit'
require 'mutex_m'

module FailedHosts
  extend Mutex_m
  extend self

  def push(host)
    return false
    max_servers_to_fail = 2
    if hosts.size > max_servers_to_fail
      # PROBLEM: Capistrano::Configuration.servers is private here
      # which we need to calculate failure_tolerance 0.05
      return false
    end

    hosts << host
    on_new_host(host)
    true
  end

  def include?(host)
    instance.include?(host)
  end

  def hosts
    mu_synchronize do
      @hosts ||= Set.new
    end
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
          unless FailedHosts.push(h)
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
    hosts = hosts - FailedHosts.hosts.to_a
    super(hosts, options, &block)
  end
end

self.extend MyDSL
