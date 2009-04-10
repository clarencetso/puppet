require 'puppet/indirector'

# Handle routing indirections.  Provides a means of declaring
# default routes and configuring them externally.
class Puppet::Indirector::Router
    require 'puppet/indirector/router/route'

    def self.default
        unless defined?(@default)
            @default = new()
        end
        @default
    end

    def initialize
        @routes = []
    end

    def cache(indirection, arguments)
        route = build_route(indirection, arguments)

        unless route.cache
            raise ArgumentError, "You must specify ':in' to determine the cache terminus"
        end
    end

    def route(indirection, arguments)
        route = build_route(indirection, arguments)

        unless route.terminus
            p route
            raise ArgumentError, "You must specify ':to' to determine the cache terminus"
        end
    end

    def cache_terminus(indirection)
        if route = find_route(indirection)
            route.cache
        end
    end

    def terminus(indirection)
        if route = find_route(indirection)
            route.terminus
        end
    end

    private

    def build_route(indirection, arguments)
        indirection = munge_indirection(indirection)
        arguments = munge_arguments(arguments)

        route = Route.new(indirection)

        configure_route(route, arguments)

        @routes << route
        route
    end

    def configure_route(route, arguments)
        arguments.each do |param, value|
            case param
            when :for; route.executable = value
            when :to; route.terminus = value
            when :in; route.cache = value
            else
                raise ArgumentError, "Invalid route parameter %s" % param
            end
        end
    end

    def find_route(indirection)
        indirection = munge_indirection(indirection)

        program = Puppet[:name].to_sym

        if route = @routes.find { |r| r.indirection == indirection and r.executable == program }
            return route
        end

        return nil unless instance = Puppet::Indirector::Indirection.instance(indirection)
        instance.default_route
    end

    def munge_arguments(arguments)
        arguments.inject({}) do |hash, ary|
            hash[ary[0].to_sym] = ary[1].to_sym
            hash
        end
    end

    def munge_indirection(indirection)
        indirection.to_sym
    end
end
