#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../../spec_helper'
require 'puppet/file_serving/mount/plugins'

describe Puppet::FileServing::Mount::Plugins, "when finding files" do
    before do
        @mount = Puppet::FileServing::Mount::Plugins.new("modules")

        @environment = stub 'environment', :module => nil
        @mount.stubs(:environment).returns @environment
    end

    it "should use the node's environment to find the modules" do
        env = mock 'env'
        @mount.expects(:environment).with("mynode").returns env
        env.expects(:modules).returns []

        @mount.find("foo", :node => "mynode")
    end

    it "should return nil if no module can be found with a matching plugin" do
        mod = mock 'module'
        mod.stubs(:plugin).with("foo/bar").returns nil

        @environment.expects(:modules).returns [mod]
        @mount.find("foo/bar").should be_nil
    end

    it "should return the file path from the module" do
        mod = mock 'module'
        mod.stubs(:plugin).with("foo/bar").returns "eh"

        @environment.expects(:modules).returns [mod]
        @mount.find("foo/bar").should == "eh"
    end
end

describe Puppet::FileServing::Mount::Plugins, "when searching for files" do
    before do
        @mount = Puppet::FileServing::Mount::Plugins.new("modules")

        @environment = stub 'environment', :module => nil
        @mount.stubs(:environment).returns @environment
    end

    it "should use the node's environment to find the modules" do
        env = mock 'env'
        @mount.expects(:environment).with("mynode").returns env
        env.expects(:modules).returns []

        @mount.search("foo", :node => "mynode")
    end

    it "should return nil if no plugin directories can be found" do
        mod = Puppet::Module.new("foo")
        mod.stubs(:paths).returns []

        @environment.expects(:modules).returns [mod]
        @mount.search("foo/bar").should be_nil
    end

    it "should return the plugin paths for each module that has plugins" do
        modules = []
        FileTest.stubs(:exist?).returns true

        2.times do |i|
            # Use real modules, so it's more of an integration test.
            modules << Puppet::Module.new("module%s" % i)
            modules[-1].stubs(:paths).returns(["/a%s" % i, "/b%s" % i])
        end

        @environment.expects(:modules).returns modules
        @mount.search("foo/bar").should == %w{/a0/plugins /b0/plugins /a1/plugins /b1/plugins}
    end
end
