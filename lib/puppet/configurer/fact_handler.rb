require 'puppet/indirector/facts/facter'

require 'puppet/configurer/downloader'

# Break out the code related to facts.  This module is
# just included into the agent, but having it here makes it
# easier to test.
module Puppet::Configurer::FactHandler
    def download_fact_plugins?
        Puppet[:factsync]
    end

    def find_facts
        reload_facter()

        # This works because puppetd configures Facts to use 'facter' for
        # finding facts and the 'rest' terminus for caching them.  Thus, we'll
        # compile them and then "cache" them on the server.
        begin
            Puppet::Node::Facts.find(Puppet[:certname])
        rescue => detail
            puts detail.backtrace if Puppet[:trace]
            raise Puppet::Error, "Could not retrieve local facts: %s" % detail
        end
    end

    def facts_for_uploading
        facts = find_facts
        #format = facts.class.default_format

        # Hard-code yaml, because I couldn't get marshal to work.
        format = :yaml

        text = facts.render(format)

        return {:facts_format => format, :facts => URI.escape(text)}
    end

    # Retrieve facts from the central server.
    def download_fact_plugins
        return unless download_fact_plugins?

        Puppet::Configurer::Downloader.new("fact", Puppet[:factdest], Puppet[:factsource], Puppet[:factsignore]).evaluate
    end

    # Clear out all of the loaded facts and reload them from disk.
    # NOTE: This is clumsy and shouldn't be required for later (1.5.x) versions
    # of Facter.
    def reload_facter
        Facter.clear

        # Reload everything.
        if Facter.respond_to? :loadfacts
            Facter.loadfacts
        elsif Facter.respond_to? :load
            Facter.load
        else
            Puppet.warning "You should upgrade your version of Facter to at least 1.3.8"
        end

        # This loads all existing facts and any new ones.  We have to remove and
        # reload because there's no way to unload specific facts.
        Puppet::Node::Facts::Facter.load_fact_plugins()
    end
end
