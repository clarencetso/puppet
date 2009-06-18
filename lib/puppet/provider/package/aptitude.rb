Puppet::Type.type(:package).provide :aptitude, :parent => :apt, :source => :dpkg do
    desc "Package management via ``aptitude``."

    has_feature :versionable

    commands :aptitude => "/usr/bin/aptitude"
    commands :aptcache => "/usr/bin/apt-cache"

    ENV['DEBIAN_FRONTEND'] = "noninteractive"

    def aptget(*args)
        args.flatten!
        # Apparently aptitude hasn't always supported a -q flag.
        if args.include?("-q")
            args.delete("-q")
        end

        #Do a dry run to make sure the version exists - Otherwise, aptitude ends up
        #installing the latest version if it can't find the version
        #Also check for any unmet dependencies from Aptitude
        if args.include?(:install)
            args_dry_run = Array.new(args)
            args_dry_run.push("-s")
            output = aptitude(*args_dry_run)
            if output =~ /Unable to find a version/
                raise Puppet::Error.new(
                    "Could not find specified version for package %s" % self.name
                )
            elsif output =~ /unmet dependencies/
                raise Puppet::Error.new(
                    "Package %s has unmet dependencies" % self.name
                )
            end
        end

        output = aptitude(*args)

        # Yay, stupid aptitude doesn't throw an error when the package is missing.
        #Also check for 404 Not Founds from the repositories used
        if args.include?(:install)
            if output =~ /Couldn't find any package/
                raise Puppet::Error.new(
                    "Could not find package %s" % self.name
                )
            elsif output =~ /404 Not Found/
                raise Puppet::Error.new(
                    "Repository returned a 404 Not Found for package %s" % self.name
                )
            end
        end
    end

    def purge
        aptitude '-y', 'purge', @resource[:name]
	end
end

