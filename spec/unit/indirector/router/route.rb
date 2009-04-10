#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../../spec_helper'

require 'puppet/indirector/router/route'

describe Puppet::Indirector::Router::Route do
    it "should require an indirection name" do
        lambda { Puppet::Indirector::Router::Route.new }.should raise_error(ArgumentError)
    end

    it "should support a executable name" do
        route = Puppet::Indirector::Router::Route.new(:catalog)
        route.executable = :puppetd
        route.executable.should == :puppetd
    end

    it "should support a terminus" do
        route = Puppet::Indirector::Router::Route.new(:catalog)
        route.terminus = :compiler
        route.terminus.should == :compiler
    end

    it "should support a cache terminus" do
        route = Puppet::Indirector::Router::Route.new(:catalog)
        route.cache = :compiler
        route.cache.should == :compiler
    end
end
