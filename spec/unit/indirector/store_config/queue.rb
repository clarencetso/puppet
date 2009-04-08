#!/usr/bin/env rails

require File.dirname(__FILE__) + '/../../../spec_helper'
require 'spec/mocks'
require 'puppet/indirector/store_config/queue'

describe Puppet::Node::StoreConfig::Queue do
    it 'writes to queue as YAML on save' do
        @client = Object.new
        class << @client
            def send(queue, obj)
                {:queue => queue, :data => obj}
            end
        end
        Puppet::Node::StoreConfig::Queue.stub!(:client).and_return(@client)

        @node = stub('node', :name => 'my_name')
        @catalog = stub('catalog', :name => 'my_name', :vertices => [:a, :b, :c])
        Puppet::Node::StoreConfig.terminus_class = :queue
        @store_config = Puppet::Node::StoreConfig.new(@node, @catalog)
        copy = @store_config.save
        copy[:data].should == YAML.dump(@store_config)
        copy[:queue].should == :store_config
    end
end

