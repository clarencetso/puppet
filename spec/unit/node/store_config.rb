#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'
require 'puppet/node/store_config'
require 'spec/mocks'

describe Puppet::Node::StoreConfig do
    before :each do
        @class = Puppet::Node::StoreConfig
        @node = stub('node', :name => 'test_node')
        @catalog = stub('catalog', :name => @node.name, :vertices => ['a', 'b', 'c'])
    end

    it 'defaults name to that of the node' do
        obj = @class.new(@node, @catalog)
        obj.name.should == @node.name
    end

    it 'accepts a node and a catalog, and transforms the catalog vertices to resources' do
        obj = @class.new(@node, @catalog)
        obj.node.should == @node
        obj.resources.should == @catalog.vertices
    end

    it 'resets resources when the catalog is changed' do
        cat = stub('alt_catalog', :name => @node.name, :vertices => [1, 2, 3, 4])
        obj = @class.new(@node, cat)
        obj.resources.should == cat.vertices
        obj.catalog = @catalog
        obj.resources.should == @catalog.vertices
    end

    it 'prohibits direct setting of resources' do
        lambda { @class.new(@node, @catalog).resources = :foo }.should raise_error
    end

    it 'is indirected with :active_record by default' do
        @class.indirection.terminus_class.should == :active_record
    end

    it 'has no indirected cache class by default' do
        @class.indirection.cache_class.should be_nil
    end
end

