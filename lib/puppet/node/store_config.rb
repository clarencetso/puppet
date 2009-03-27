require 'puppet/indirector'

class Puppet::Node::StoreConfig
    attr_accessor :node, :resources

    extend Puppet::Indirector
    indirects :store_config, :terminus_class => :active_record

    def initialize(node, catalog)
        self.node = node
        self.catalog = catalog
    end

    def catalog=(cat)
        self.resources = cat.vertices
        cat
    end

    def name
        self.node.name
    end

    private :resources=
end
