require 'puppet/indirector/terminus'

class Puppet::Indirector::ActiveRecord < Puppet::Indirector::Terminus
    def save(*arg)
        assert_connected
        _save(*arg)
    end

    def find(*arg)
        assert_connected
        _find(*arg)
    end

    def search(*arg)
        assert_connected
        _search(*arg)
    end

    def assert_connected
        unless Puppet.features.rails?
            raise Puppet::Error, 'Rails is not available for ActiveRecord use'
        end
        Puppet::Rails.connect unless ActiveRecord::Base.connected?
        true
    end

    def _save(*arg)
    end

    def _find(*arg)
    end

    def _search(*arg)
    end
end
