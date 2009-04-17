#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'

require 'puppet/parser/files'

describe Puppet::Parser::Files do
    it "should have a method for finding a template" do
        Puppet::Parser::Files.should respond_to(:find_template)
    end

    it "should have a method for finding manifests" do
        Puppet::Parser::Files.should respond_to(:find_manifests)
    end

    describe "when searching for templates" do
        it "should return fully-qualified templates directly" do
            Puppet::Parser::Files.expects(:modulepath).never
            Puppet::Parser::Files.find_template("/my/template").should == "/my/template"
        end

        it "should return the template from the first found module" do
            mod = mock 'module'
            Puppet::Node::Environment.new.expects(:module).with("mymod").returns mod

            mod.expects(:template).returns("/one/mymod/templates/mytemplate")
            Puppet::Parser::Files.find_template("mymod/mytemplate").should == "/one/mymod/templates/mytemplate"
        end
        
        it "should return the file in the templatedir if it exists" do
            Puppet.settings.expects(:value).with(:templatedir, nil).returns("/my/templates")
            Puppet[:modulepath] = "/one:/two"
            File.stubs(:directory?).returns(true)
            FileTest.stubs(:exist?).returns(true)
            Puppet::Parser::Files.find_template("mymod/mytemplate").should == "/my/templates/mymod/mytemplate"
        end

        it "should raise an error if no valid templatedir exists" do
            Puppet::Parser::Files.stubs(:templatepath).with(nil).returns(nil)
            lambda { Puppet::Parser::Files.find_template("mytemplate") }.should raise_error
        end

        it "should not raise an error if no valid templatedir exists and the template exists in a module" do
            mod = mock 'module'
            Puppet::Node::Environment.new.expects(:module).with("mymod").returns mod

            mod.expects(:template).returns("/one/mymod/templates/mytemplate")
            Puppet::Parser::Files.stubs(:templatepath).with(nil).returns(nil)

            Puppet::Parser::Files.find_template("mymod/mytemplate").should == "/one/mymod/templates/mytemplate"
        end

        it "should use the main templatedir if no module is found" do
            Puppet::Parser::Files.stubs(:templatepath).with(nil).returns(["/my/templates"])
            Puppet::Module.expects(:find).with("mymod", nil).returns(nil)
            Puppet::Parser::Files.find_template("mymod/mytemplate").should == "/my/templates/mymod/mytemplate"
        end

        it "should return unqualified templates directly in the template dir" do
            Puppet::Parser::Files.stubs(:templatepath).with(nil).returns(["/my/templates"])
            Puppet::Module.expects(:find).never
            Puppet::Parser::Files.find_template("mytemplate").should == "/my/templates/mytemplate"
        end

        it "should accept relative templatedirs" do
            Puppet[:templatedir] = "my/templates"
            File.expects(:directory?).with(File.join(Dir.getwd,"my/templates")).returns(true)
            Puppet::Parser::Files.find_template("mytemplate").should == File.join(Dir.getwd,"my/templates/mytemplate")
        end

        it "should use the environment templatedir if no module is found and an environment is specified" do
            Puppet::Parser::Files.stubs(:templatepath).with("myenv").returns(["/myenv/templates"])
            Puppet::Module.expects(:find).with("mymod", "myenv").returns(nil)
            Puppet::Parser::Files.find_template("mymod/mytemplate", "myenv").should == "/myenv/templates/mymod/mytemplate"
        end

        it "should use first dir from environment templatedir if no module is found and an environment is specified" do
            Puppet::Parser::Files.stubs(:templatepath).with("myenv").returns(["/myenv/templates", "/two/templates"])
            Puppet::Module.expects(:find).with("mymod", "myenv").returns(nil)
            Puppet::Parser::Files.find_template("mymod/mytemplate", "myenv").should == "/myenv/templates/mymod/mytemplate"
        end

        it "should use a valid dir when templatedir is a path for unqualified templates and the first dir contains template" do
            Puppet::Parser::Files.stubs(:templatepath).returns(["/one/templates", "/two/templates"])
            FileTest.expects(:exist?).with("/one/templates/mytemplate").returns(true)
            Puppet::Module.expects(:find).never
            Puppet::Parser::Files.find_template("mytemplate").should == "/one/templates/mytemplate"
        end

        it "should use a valid dir when templatedir is a path for unqualified templates and only second dir contains template" do
            Puppet::Parser::Files.stubs(:templatepath).returns(["/one/templates", "/two/templates"])
            FileTest.expects(:exist?).with("/one/templates/mytemplate").returns(false)
            FileTest.expects(:exist?).with("/two/templates/mytemplate").returns(true)
            Puppet::Module.expects(:find).never
            Puppet::Parser::Files.find_template("mytemplate").should == "/two/templates/mytemplate"
        end

        it "should use the node environment if specified" do
            mod = mock 'module'
            Puppet::Node::Environment.new("myenv").expects(:module).with("mymod").returns mod

            mod.expects(:template).returns("/my/modules/mymod/templates/envtemplate")

            Puppet::Parser::Files.find_template("mymod/envtemplate", "myenv").should == "/my/modules/mymod/templates/envtemplate"
        end

        after { Puppet.settings.clear }
    end

    describe "when searching for manifests when no module is found" do
        before do
            File.stubs(:find).returns(nil)
        end

        it "should not look for modules when paths are fully qualified" do
            Puppet.expects(:value).with(:modulepath).never
            file = "/fully/qualified/file.pp"
            Dir.stubs(:glob).with(file).returns([file])
            Puppet::Parser::Files.find_manifests(file)
        end

        it "should directly return fully qualified files" do
            file = "/fully/qualified/file.pp"
            Dir.stubs(:glob).with(file).returns([file])
            Puppet::Parser::Files.find_manifests(file).should == [file]
        end

        it "should match against provided fully qualified patterns" do
            pattern = "/fully/qualified/pattern/*"
            Dir.expects(:glob).with(pattern).returns(%w{my file list})
            Puppet::Parser::Files.find_manifests(pattern).should == %w{my file list}
        end

        it "should look for files relative to the current directory" do
            cwd = Dir.getwd
            Dir.expects(:glob).with("#{cwd}/foobar/init.pp").returns(["#{cwd}/foobar/init.pp"])
            Puppet::Parser::Files.find_manifests("foobar/init.pp").should == ["#{cwd}/foobar/init.pp"]
        end

        it "should only return files, not directories" do
            pattern = "/fully/qualified/pattern/*"
            file = "/my/file"
            dir = "/my/directory"
            Dir.expects(:glob).with(pattern).returns([file, dir])
            FileTest.expects(:directory?).with(file).returns(false)
            FileTest.expects(:directory?).with(dir).returns(true)
            Puppet::Parser::Files.find_manifests(pattern).should == [file]
        end
    end

    describe "when searching for manifests in a found module" do
        before do
            @module = Puppet::Module.new("mymod", "/one")
        end

        it "should return the manifests from the first found module" do
            mod = mock 'module'
            Puppet::Node::Environment.new.expects(:module).with("mymod").returns mod
            mod.expects(:match_manifests).with("init.pp").returns(%w{/one/mymod/manifests/init.pp})
            Puppet::Parser::Files.find_manifests("mymod/init.pp").should == ["/one/mymod/manifests/init.pp"]
        end

        it "should use the node environment if specified" do
            mod = mock 'module'
            Puppet::Node::Environment.new("myenv").expects(:module).with("mymod").returns mod
            mod.expects(:match_manifests).with("init.pp").returns(%w{/one/mymod/manifests/init.pp})
            Puppet::Parser::Files.find_manifests("mymod/init.pp", :environment => "myenv").should == ["/one/mymod/manifests/init.pp"]
        end

        it "should return all manifests matching the glob pattern" do
            File.stubs(:directory?).returns(true)
            Dir.expects(:glob).with("/one/manifests/yay/*.pp").returns(%w{/one /two})

            @module.match_manifests("yay/*.pp").should == %w{/one /two}
        end

        it "should not return directories" do
            Dir.expects(:glob).with("/one/manifests/yay/*.pp").returns(%w{/one /two})

            FileTest.expects(:directory?).with("/one").returns false
            FileTest.expects(:directory?).with("/two").returns true

            @module.match_manifests("yay/*.pp").should == %w{/one}
        end

        it "should default to the 'init.pp' file in the manifests directory" do
            Dir.expects(:glob).with("/one/manifests/init.pp").returns(%w{/init.pp})

            @module.match_manifests(nil).should == %w{/init.pp}
        end

        after { Puppet.settings.clear }
    end
end
