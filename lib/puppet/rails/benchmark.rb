require 'benchmark'
module Puppet::Rails::Benchmark
    def railsmark(message)
        seconds = Benchmark.realtime { yield }
        Puppet.debug(message + " %0.2f seconds" % seconds)
    end

    def sometimes_benchmark(message)
        yield and return unless Puppet::Rails::TIME_DEBUG

        railsmark(message) { yield }
    end
end
