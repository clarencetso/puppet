#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../../spec_helper'
require 'puppet/indirector/store_config/active_record'
require 'spec/mocks'

describe Puppet::Node::StoreConfig::ActiveRecord do
    it 'should delegate to Puppet::Rails::Node.store() for save()' do
        @node = stub('node', :name => 'some_special_node')
        @catalog = stub('catalog', :vertices => [:some, :special, :catalog])

        Puppet.features.stub!(:rails?).and_return(true)
        ActiveRecord = Class.new unless defined? ActiveRecord
        ActiveRecord::Base = Class.new unless defined? ActiveRecord::Base
        ActiveRecord::Base.stub!(:connected?).and_return(true)

        Puppet::Rails = Module.new() unless defined? Puppet::Rails
        Puppet::Rails::Host = Module.new() unless defined? Puppet::Rails::Host

        Puppet::Node::StoreConfig.terminus_class = :active_record
        store = Puppet::Node::StoreConfig.new(@node, @catalog)
        # it's fairly frustrating that .should_receive doesn't seem to ever fail;
        # a lying test is worse than no test at all.  But here's a comment for it,
        # in any case.
        Puppet::Rails::Host.should_receive(:store).with(@node, @catalog.vertices)
        store.save
    end
end

