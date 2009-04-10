#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'
require 'puppet/indirector/router'

describe Puppet::Indirector::Router do
    it "should support declaring routes" do
        Puppet::Indirector::Router.new.should respond_to(:route)
    end

    it "should have a default, global router" do
        Puppet::Indirector::Router.default.should be_instance_of(Puppet::Indirector::Router)
    end

    it "should always use the same default router" do
        Puppet::Indirector::Router.default.should equal(Puppet::Indirector::Router.default)
    end

    it "should be able to return a terminus for a given indirection" do
        Puppet::Indirector::Router.new.should respond_to(:terminus)
    end

    it "should be able to return a cache for a given indirection" do
        Puppet::Indirector::Router.new.should respond_to(:cache)
    end

    describe "when routing" do
        before do
            @router = Puppet::Indirector::Router.new
            Puppet.settings.stubs(:[]).with(:name).returns "myprog"
        end

        it "should be able to return the terminus for a previously routed indirection" do
            @router.route(:catalog, :for => "myprog", :to => :myterminus)

            @router.terminus(:catalog).should == :myterminus
        end

        it "should be able to return the cache terminus for a previously routed indirection" do
            @router.cache(:catalog, :for => "myprog", :in => :mycache)

            @router.cache_terminus(:catalog).should == :mycache
        end

        it "should choose the appopriate executable routes based on the executable name" do
            Puppet.settings.expects(:[]).with(:name).returns "yayprog"

            @router.route(:catalog, :for => "yayprog", :to => :yayterminus)
            @router.route(:catalog, :for => "otherprog", :to => :othercache)

            @router.terminus(:catalog).should == :yayterminus
        end

        it "should support executables specified as symbols" do
            @router.route(:catalog, :for => :myprog, :to => :myterminus)

            @router.terminus(:catalog).should == :myterminus
        end

        it "should support indirection names specified as symbols or strings" do
            @router.route("catalog", :for => :myprog, :to => :myterminus)

            @router.terminus("catalog").should == :myterminus
        end

        it "should use the indirection's default route if no route is matched" do
            route = mock 'route', :terminus => :foo

            indirection = mock 'indirection', :default_route => route
            Puppet::Indirector::Indirection.expects(:instance).returns indirection

            @router.terminus("catalog").should == :foo
        end

        it "should return nil if no route is matched and no default route is found" do
            indirection = mock 'indirection', :default_route => nil
            Puppet::Indirector::Indirection.expects(:instance).returns indirection

            @router.terminus("catalog").should be_nil
        end

        it "should return nil if no indirection can be found to route" do
            Puppet::Indirector::Indirection.expects(:instance).returns nil

            @router.terminus("catalog").should be_nil
        end
    end
end
