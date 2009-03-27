#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'
require 'puppet/indirector/active_record'
require 'spec/mocks'

# stubbing this stuff with rspec was extremely problematic, so doing it directly
module ActiveRecord
    class Base
        class << self
            attr_accessor :connect_state
            def connected?
                return connect_state
            end
        end
    end
end

describe Puppet::Indirector::ActiveRecord do
    before :each do
        @indirection = stub 'indirector', :name => :my_active_record, :register_terminus_type => nil
        Puppet::Indirector::Indirection.stubs(:instance).with(:my_active_record).returns(@indirection)
        @class = Class.new(Puppet::Indirector::ActiveRecord) do
            def self.to_s
                'MyActiveRecord::Test'
            end
        end
        @store = @class.new
        Puppet.features.stub!(:rails?).and_return(true)
        ActiveRecord::Base.connect_state = true
    end

    it 'should throw exceptions for standard operations if Rails is unavailable' do
        Puppet.features.stub!(:rails?).and_return(false)
        lambda { @store.save }.should raise_error
        lambda { @store.find }.should raise_error
        lambda { @store.search }.should raise_error
    end

    it 'connects as necessary if Rails is available but unconnected' do
        ActiveRecord::Base.connect_state = false
        ActiveRecord::Base.should_receive(:connect).exactly(3).times
        @store.save
        @store.find
        @store.search
    end

    it 'dispatches each standard operation to a privately-named equivalent method' do
        @save = ['a', 'b', 'c']
        @find = ['d', 'e', 'f']
        @search = ['g', 'h', 'i']
        @store.should_receive(:_save).with(*@save)
        @store.should_receive(:_find).with(*@find)
        @store.should_receive(:_search).with(*@search)
        @store.save(*@save)
        @store.find(*@find)
        @store.search(*@search)
    end
end

