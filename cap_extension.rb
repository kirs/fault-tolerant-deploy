require 'thread'
require 'sshkit'

module SSHKit
  module Runner
    class ParallelFaultTolerant < Abstract
      def execute
        threads = []
        hosts.each do |host|
          threads << Thread.new(host) do |h|
            begin
              backend(h, &block).run
            rescue StandardError => e
              e2 = ExecuteError.new e
              b = backend(h)
              # instead of raising an error as in Parallel runner, we aim to log it
              b.error "Exception while executing #{host.user ? "as #{host.user}@" : "on host "}#{host}: #{e.message}"
            end
          end
        end
        threads.map(&:join)
      end
    end

  end

end
