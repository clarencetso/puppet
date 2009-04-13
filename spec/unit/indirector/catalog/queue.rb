#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../../spec_helper'

require 'puppet/indirector/catalog/queue'

describe Puppet::Node::Catalog::Queue do
    it 'should be a subclass of the Queue terminus' do
        Puppet::Node::Catalog::Queue.superclass.should equal(Puppet::Indirector::Queue)
    end

    it 'should be registered with the catalog store indirection' do
        indirection = Puppet::Indirector::Indirection.instance(:catalog)
        Puppet::Node::Catalog::Queue.indirection.should equal(indirection)
    end

    it 'shall be dubbed ":queue"' do
        Puppet::Node::Catalog::Queue.name.should == :queue
    end
end
