require 'benchmark'
module Puppet::Rails::Benchmark
    def railsmark(message)
        seconds = Benchmark.realtime { yield }
        Puppet.debug(message + " in %0.2f seconds" % seconds)
    end

    def sometimes_benchmark(message)
        yield and return unless Puppet::Rails::TIME_DEBUG

        railsmark(message) { yield }
    end

    # Collect partial benchmarks to be logged when they're
    # all done.
    #   These are always low-level debugging so we only
    # print them if time_debug is enabled.
    def accumulate_benchmark(message, label)
        yield and return unless Puppet::Rails::TIME_DEBUG

        $accumulated_benchmarks ||= {}
        $accumulated_benchmarks[message] ||= Hash.new(0)
        $accumulated_benchmarks[message][label] += Benchmark.realtime { yield }
    end

    # Log the accumulated marks.
    def log_accumulated_marks(message)
        return unless Puppet::Rails::TIME_DEBUG

        if $accumulated_benchmarks.empty? or $accumulated_benchmarks[message].empty?
            Puppet.debug(message + " in %0.2f seconds" % 0)
            return
        end

        $accumulated_benchmarks[message].each do |label, value|
            Puppet.debug(message + ("(%s)" % label) + (" in %0.2f seconds" % value))
        end
        $accumulated_benchmarks.delete(message)
    end
end
