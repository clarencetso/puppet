require 'puppet/indirector'

class Puppet::Node::StoreConfig
    attr_accessor :node, :resources, :transportable

    extend Puppet::Indirector
    indirects :store_config, :terminus_class =>  :active_record

    def initialize(node, catalog)
        self.node = node
        self.catalog = catalog
        self.transportable = catalog.to_transportable
    end

    def catalog=(cat)
        self.resources = cat.vertices
        cat
    end

    def name
        self.node.name
    end

    def to_host
        Puppet::Rails::Host.find_or_create_by_name(self.node.name)
    end
    private :resources=
end