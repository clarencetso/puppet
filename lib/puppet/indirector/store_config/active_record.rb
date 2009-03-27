require 'puppet/indirector/active_record'
require 'puppet/node/store_config'
require 'puppet/rails/host'

class Puppet::Node::StoreConfig::ActiveRecord < Puppet::Indirector::ActiveRecord
    def save(request)
        Puppet::Rails::Host.store(request.instance.node, request.instance.resources)
    end
end

