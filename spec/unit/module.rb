#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../spec_helper'

describe Puppet::Module do
    it "should require a name at initialization" do
        lambda { Puppet::Module.new }.should raise_error(ArgumentError)
    end

    it "should convert an environment name into an Environment instance" do
        Puppet::Module.new("foo", "prod").environment.should be_instance_of(Puppet::Node::Environment)
    end

    it "should accept an environment at initialization" do
        Puppet::Module.new("foo", :prod).environment.name.should == :prod
    end

    it "should use the default environment if none is provided" do
        env = Puppet::Node::Environment.new
        Puppet::Module.new("foo").environment.should equal(env)
    end

    it "should use any provided Environment instance" do
        env = Puppet::Node::Environment.new
        Puppet::Module.new("foo", env).environment.should equal(env)
    end

    it "should be able to find all of its instances in all of the module paths and should return them in the order they're in the module path" do
        mod = Puppet::Module.new("foo")
        paths = %w{/a /b /c}
        Puppet::Module.stubs(:modulepath).returns paths

        FileTest.expects(:exist?).with("/a/foo").returns true
        FileTest.expects(:exist?).with("/b/foo").returns false
        FileTest.expects(:exist?).with("/c/foo").returns true

        mod.paths.should == %w{/a/foo /c/foo}
    end

    it "should be considered existent if it exists in at least one module path" do
        mod = Puppet::Module.new("foo")
        mod.expects(:paths).returns %w{/a/foo /b/foo}
        mod.should be_exist
    end

    it "should be considered nonexistent if it does not exist in any of the module paths" do
        mod = Puppet::Module.new("foo")
        mod.expects(:paths).returns []
        mod.should_not be_exist
    end

    [:plugins, :templates, :files, :manifests].each do |filetype|
        it "should be able to return individual #{filetype}" do
            mod = Puppet::Module.new("foo")
            mod.stubs(:paths).returns %w{/a/foo}
            path = File.join("/a/foo", filetype.to_s, "my/file")
            FileTest.expects(:exist?).with(path).returns true
            mod.send(filetype.to_s.sub(/s$/, ''), "my/file").should == path
        end

        it "should return the first found #{filetype.to_s.sub(/s$/, '')} that exists" do
            mod = Puppet::Module.new("foo")
            mod.stubs(:paths).returns %w{/a/foo /b/foo}
            path = File.join("/a/foo", filetype.to_s, "my/file")
            FileTest.expects(:exist?).with(path).returns true
            mod.send(filetype.to_s.sub(/s$/, ''), "my/file").should == path
        end

        it "should return #{filetype} from later paths if they don't exist in the first path" do
            mod = Puppet::Module.new("foo")
            mod.stubs(:paths).returns %w{/a/foo /b/foo}
            first = File.join("/a/foo", filetype.to_s, "my/file")
            second = File.join("/b/foo", filetype.to_s, "my/file")
            FileTest.expects(:exist?).with(first).returns false
            FileTest.expects(:exist?).with(second).returns true
            mod.send(filetype.to_s.sub(/s$/, ''), "my/file").should == second
        end

        it "should return nil if asked to return individual #{filetype} that don't exist" do
            mod = Puppet::Module.new("foo")
            mod.stubs(:paths).returns %w{/a/foo}
            path = File.join("/a/foo", filetype.to_s, "my/file")
            FileTest.expects(:exist?).with(path).returns false
            mod.send(filetype.to_s.sub(/s$/, ''), "my/file").should be_nil
        end

        it "should return nil when asked for individual #{filetype} if the module does not exist" do
            mod = Puppet::Module.new("foo")
            mod.stubs(:paths).returns []
            mod.send(filetype.to_s.sub(/s$/, ''), "my/file").should be_nil
        end

        it "should return the first existing base directory if asked for a nil path" do
            mod = Puppet::Module.new("foo")
            mod.stubs(:paths).returns %w{/a/foo /b/foo /c/foo}
            first = File.join("/a/foo", filetype.to_s)
            second = File.join("/b/foo", filetype.to_s)
            FileTest.expects(:exist?).with(first).returns false
            FileTest.expects(:exist?).with(second).returns true
            mod.send(filetype.to_s.sub(/s$/, ''), nil).should == second
        end
    end

    %w{plugins files}.each do |type|
        short = type.sub(/s$/, '')
        it "should be able to return a list of #{short} directories" do
            Puppet::Module.new("foo").should respond_to(short + "_directories")
        end

        it "should return all #{short} directories that exist in its list of paths" do
            mod = Puppet::Module.new("foo")
            mod.stubs(:paths).returns %w{/a/foo /b/foo /c/foo}
            first = File.join("/a/foo/#{type}")
            second = File.join("/b/foo/#{type}")
            third = File.join("/c/foo/#{type}")
            FileTest.expects(:exist?).with(first).returns true
            FileTest.expects(:exist?).with(second).returns true
            FileTest.expects(:exist?).with(third).returns false
            mod.send(short + "_directories").should == ["/a/foo/#{type}", "/b/foo/#{type}"]
        end
    end
end

describe Puppet::Module, "when yielding each module in a list of directories" do
    before do
        FileTest.stubs(:directory?).returns true
    end

    it "should search for modules in each directory in the list" do
        Dir.expects(:entries).with("/one").returns []
        Dir.expects(:entries).with("/two").returns []

        Puppet::Module.each_module("/one", "/two")
    end

    it "should accept the list of directories as an array" do
        Dir.expects(:entries).with("/one").returns []
        Dir.expects(:entries).with("/two").returns []

        Puppet::Module.each_module(%w{/one /two})
    end

    it "should accept the list of directories joined by #{File::PATH_SEPARATOR}" do
        Dir.expects(:entries).with("/one").returns []
        Dir.expects(:entries).with("/two").returns []

        list = %w{/one /two}.join(File::PATH_SEPARATOR)

        Puppet::Module.each_module(list)
    end

    it "should not create modules for '.' or '..' in the provided directory list" do
        Dir.expects(:entries).with("/one").returns(%w{. ..})

        result = []
        Puppet::Module.each_module("/one") do |mod|
            result << mod
        end

        result.should be_empty
    end

    it "should not create modules for non-directories in the provided directory list" do
        Dir.expects(:entries).with("/one").returns(%w{notdir})

        FileTest.expects(:directory?).with("/one/notdir").returns false

        result = []
        Puppet::Module.each_module("/one") do |mod|
            result << mod
        end

        result.should be_empty
    end

    it "should yield each found module" do
        Dir.expects(:entries).with("/one").returns(%w{f1 f2})

        one = mock 'one'
        two = mock 'two'

        Puppet::Module.expects(:new).with("f1").returns one
        Puppet::Module.expects(:new).with("f2").returns two

        result = []
        Puppet::Module.each_module("/one") do |mod|
            result << mod
        end

        result.should == [one, two]
    end

    it "should not yield a module with the same name as a previously yielded module" do
        Dir.expects(:entries).with("/one").returns(%w{f1})
        Dir.expects(:entries).with("/two").returns(%w{f1})

        one = mock 'one'

        Puppet::Module.expects(:new).with("f1").returns one
        Puppet::Module.expects(:new).with("f1").never

        result = []
        Puppet::Module.each_module("/one", "/two") do |mod|
            result << mod
        end

        result.should == [one]
    end
end

describe Puppet::Module, " when building its search path" do
    it "should use the current environment's search path if no environment is specified" do
        env = mock 'env'
        env.expects(:modulepath).returns "eh"
        Puppet::Node::Environment.expects(:new).with(nil).returns env

        Puppet::Module.modulepath.should == "eh"
    end

    it "should use the specified environment's search path if an environment is specified" do
        env = mock 'env'
        env.expects(:modulepath).returns "eh"
        Puppet::Node::Environment.expects(:new).with("foo").returns env

        Puppet::Module.modulepath("foo").should == "eh"
    end
end

describe Puppet::Module, "when finding matching manifests" do
    it "should return all manifests matching the glob pattern" do
        mod = Puppet::Module.new("mymod")
        mod.stubs(:paths).returns %w{/a}
        Dir.expects(:glob).with("/a/manifests/yay/*.pp").returns(%w{foo bar})

        mod.match_manifests("yay/*.pp").should == %w{foo bar}
    end

    it "should not return directories" do
        mod = Puppet::Module.new("mymod")
        mod.stubs(:paths).returns %w{/a}
        Dir.expects(:glob).with("/a/manifests/yay/*.pp").returns(%w{foo bar})

        FileTest.expects(:directory?).with("foo").returns false
        FileTest.expects(:directory?).with("bar").returns true
        mod.match_manifests("yay/*.pp").should == %w{foo}
    end

    it "should default to the 'init.pp' file if no glob pattern is specified" do
        mod = Puppet::Module.new("mymod")
        mod.stubs(:paths).returns %w{/a}
        FileTest.stubs(:exist?).returns true

        mod.match_manifests(nil).should == %w{/a/manifests/init.pp}
    end

    it "should return all manifests matching the glob pattern in all existing paths" do
        mod = Puppet::Module.new("mymod")
        mod.stubs(:paths).returns %w{/a /b}
        Dir.expects(:glob).with("/a/manifests/yay/*.pp").returns(%w{a b})
        Dir.expects(:glob).with("/b/manifests/yay/*.pp").returns(%w{c d})

        mod.match_manifests("yay/*.pp").should == %w{a b c d}
    end

    it "should match the glob pattern plus '.pp' if no results are found" do
        mod = Puppet::Module.new("mymod")
        mod.stubs(:paths).returns %w{/a}
        Dir.expects(:glob).with("/a/manifests/yay/foo").returns([])
        Dir.expects(:glob).with("/a/manifests/yay/foo.pp").returns(%w{yay})

        mod.match_manifests("yay/foo").should == %w{yay}
    end

    it "should return an empty array if no manifests matched" do
        mod = Puppet::Module.new("mymod")
        mod.stubs(:paths).returns %w{/a}
        Dir.expects(:glob).with("/a/manifests/yay/*.pp").returns([])

        mod.match_manifests("yay/*.pp").should == []
    end
end
