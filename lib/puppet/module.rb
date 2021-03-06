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

                yield Puppet::Module.new(name, module_path)
            end
        end
    end
    
    # Return an array of paths by splitting the +modulepath+ config
    # parameter. Only consider paths that are absolute and existing
    # directories
    def self.modulepath(environment = nil)
        Puppet::Node::Environment.new(environment).modulepath
    end

    # Return an array of paths by splitting the +templatedir+ config
    # parameter.
    def self.templatepath(environment = nil)
        dirs = Puppet.settings.value(:templatedir, environment).split(":")
        dirs.select do |p|
            File::directory?(p)
        end
    end

    # Find and return the +module+ that +path+ belongs to. If +path+ is
    # absolute, or if there is no module whose name is the first component
    # of +path+, return +nil+
    def self.find(modname, environment = nil)
        Puppet::Node::Environment.new(environment).module(modname)
    end

    # Instance methods

    # Find the concrete file denoted by +file+. If +file+ is absolute,
    # return it directly. Otherwise try to find it as a template in a
    # module. If that fails, return it relative to the +templatedir+ config
    # param.
    # In all cases, an absolute path is returned, which does not
    # necessarily refer to an existing file
    def self.find_template(template, environment = nil)
        if template =~ /^#{File::SEPARATOR}/
            return template
        end

        if template_paths = templatepath(environment)
            # If we can find the template in :templatedir, we return that.
            td_file = template_paths.collect { |path|
                File::join(path, template)
            }.each do |f|
                return f if FileTest.exist?(f)
            end
        end

        # check in the default template dir, if there is one
        unless td_file = find_template_for_module(template, environment)
            raise Puppet::Error, "No valid template directory found, please check templatedir settings" if template_paths.nil?
            td_file = File::join(template_paths.first, template)
        end
        td_file
    end

    def self.find_template_for_module(template, environment = nil)
        path, file = split_path(template)

        # Because templates don't have an assumed template name, like manifests do,
        # we treat templates with no name as being templates in the main template
        # directory.
        return nil unless file

        if mod = find(path, environment) and t = mod.template(file)
            return t
        end
        nil
    end

    private_class_method :find_template_for_module

    # Return a list of manifests (as absolute filenames) that match +pat+
    # with the current directory set to +cwd+. If the first component of
    # +pat+ does not contain any wildcards and is an existing module, return
    # a list of manifests in that module matching the rest of +pat+
    # Otherwise, try to find manifests matching +pat+ relative to +cwd+
    def self.find_manifests(start, options = {})
        cwd = options[:cwd] || Dir.getwd
        module_name, pattern = split_path(start)
        if module_name and mod = find(module_name, options[:environment])
            return mod.match_manifests(pattern)
        else
            abspat = File::expand_path(start, cwd)
            files = Dir.glob(abspat).reject { |f| FileTest.directory?(f) }
            if files.size == 0
                files = Dir.glob(abspat + ".pp").reject { |f| FileTest.directory?(f) }
            end
            return files
        end
    end

    # Split the path into the module and the rest of the path.
    # This method can and often does return nil, so anyone calling
    # it needs to handle that.
    def self.split_path(path)
        if path =~ %r/^#{File::SEPARATOR}/
            return nil
        end

        modname, rest = path.split(File::SEPARATOR, 2)
        return nil if modname.nil? || modname.empty?
        return modname, rest
    end

    attr_reader :name, :path
    def initialize(name, path)
        @name = name
        @path = path
    end

    FILETYPES.each do |type|
        # Create a method for returning the full path to a given
        # file type's directory.
        define_method(type.to_s) do
            File.join(path, type.to_s)
        end
        # Create a boolean method for testing whether our module has
        # files of a given type.
        define_method(type.to_s + "?") do
            FileTest.exist?(send(type))
        end

        # Finally, a method for returning an individual file
        define_method(type.to_s.sub(/s$/, '')) do |file|
            if file
                path = File.join(send(type), file)
            else
                path = send(type)
            end
            return nil unless FileTest.exist?(path)
            return path
        end
    end

    # Return the list of manifests matching the given glob pattern,
    # defaulting to 'init.pp' for empty modules.
    def match_manifests(rest)
        rest ||= "init.pp"
        p = File::join(path, MANIFESTS, rest)
        files = Dir.glob(p).reject { |f| FileTest.directory?(f) }
        if files.size == 0
            files = Dir.glob(p + ".pp")
        end
        return files
    end
end
