require 'puppet/indirector/router'

class Puppet::Indirector::Router::Route
    attr_accessor :executable, :indirection, :terminus, :cache

    def initialize(indirection)
        @indirection = indirection
    end
end
