# Support for modules
class Puppet::Module

    TEMPLATES = "templates"
    FILES = "files"
    MANIFESTS = "manifests"
    PLUGINS = "plugins"

    FILETYPES = [MANIFESTS, FILES, TEMPLATES, PLUGINS]

    # Search through a list of paths, yielding each found module in turn.
    def self.each_module(*paths)
        paths = paths.flatten.collect { |p| p.split(File::PATH_SEPARATOR) }.flatten

        yielded = {}
        paths.each do |dir|
            next unless FileTest.directory?(dir)

            Dir.entries(dir).each do |name|
                next if name =~ /^\./
                next if yielded.include?(name)

                module_path = File.join(dir, name)
                next unless FileTest.directory?(module_path)

                yielded[name] = true

                yield Puppet::Module.new(name)
            end
        end
    end
    
    # Return an array of paths by splitting the +modulepath+ config
    # parameter. Only consider paths that are absolute and existing
    # directories
    def self.modulepath(environment = nil)
        Puppet::Node::Environment.new(environment).modulepath
    end

    # Find and return the +module+ that +path+ belongs to. If +path+ is
    # absolute, or if there is no module whose name is the first component
    # of +path+, return +nil+
    def self.find(modname, environment = nil)
        Puppet::Node::Environment.new(environment).module(modname)
    end

    attr_reader :name, :environment
    def initialize(name, environment = nil)
        @name = name
        if environment.is_a?(Puppet::Node::Environment)
            @environment = environment
        else
            @environment = Puppet::Node::Environment.new(environment)
        end
    end

    FILETYPES.each do |type|
        # Finally, a method for returning an individual file
        define_method(type.to_s.sub(/s$/, '')) do |file|
            paths.collect do |d|
                # If 'file' is nil then they're asking for the base path.
                # This is used for things like fileserving.
                if file
                    File.join(d, type.to_s, file)
                else
                    File.join(d, type.to_s)
                end
            end.find { |f| FileTest.exist?(f) }
        end
    end

    def exist?
        ! paths.empty?
    end

    # Find the first 'files' directory.  This is used by the XMLRPC fileserver.
    def file_directories
        subpaths("files")
    end

    # Return the list of manifests matching the given glob pattern,
    # defaulting to 'init.pp' for empty modules.
    def match_manifests(rest)
        return find_init_manifest unless rest # Use init.pp

        rest ||= "init.pp"
        paths.collect do |path|
            p = File::join(path, MANIFESTS, rest)
            result = Dir.glob(p).reject { |f| FileTest.directory?(f) }
            if result.size == 0 and rest !~ /\.pp$/
                result = Dir.glob(p + ".pp")
            end
            result
        end.flatten.compact
    end

    # Find all module paths that this module is in.
    def paths
        self.class.modulepath.collect { |path| File.join(path, name) }.find_all { |d| FileTest.exist?(d) }
    end

    # Find all plugin directories.  This is used by the Plugins fileserving mount.
    def plugin_directories
        subpaths("plugins")
    end

    private

    def find_init_manifest
        return [] unless file = subpaths("manifests").collect { |d| File.join(d, "init.pp") }.find { |f| FileTest.exist?(f) }
        return [file]
    end

    def subpaths(type)
        paths.collect { |path| File.join(path, type) }.find_all { |f| FileTest.exist?(f) }
    end
end
