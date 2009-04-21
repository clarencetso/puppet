#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../spec_helper'

require 'puppet/transaction'

describe Puppet::Transaction do
    it "should match resources by name, not title, when prefetching" do
        @catalog = Puppet::Resource::Catalog.new
        @transaction = Puppet::Transaction.new(@catalog)

        # Have both a title and name
        resource = Puppet::Type.type(:sshkey).new :title => "foo", :name => "bar", :type => :dsa, :key => "eh"
        @catalog.add_resource resource

        resource.provider.class.expects(:prefetch).with("bar" => resource)

        @transaction.prefetch
    end

    describe "when generating resources" do
        it "should finish all resources" do
            generator = stub 'generator', :depthfirst? => true
            resource = stub 'resource'

            @catalog = Puppet::Resource::Catalog.new
            @transaction = Puppet::Transaction.new(@catalog)

            generator.expects(:generate).returns [resource]

            @catalog.expects(:add_resource).yields(resource)

            resource.expects(:finish)

            @transaction.generate_additional_resources(generator, :generate)
        end

        it "should skip generated resources that conflict with existing resources" do
            generator = mock 'generator'
            resource = stub 'resource'

            @catalog = Puppet::Resource::Catalog.new
            @transaction = Puppet::Transaction.new(@catalog)

            generator.expects(:generate).returns [resource]

            @catalog.expects(:add_resource).raises(Puppet::Resource::Catalog::DuplicateResourceError.new("foo"))

            resource.expects(:finish).never
            resource.expects(:info) # log that it's skipped

            @transaction.generate_additional_resources(generator, :generate).should be_empty
        end
    end
end

describe Puppet::Transaction, " when determining tags" do
    before do
        @config = Puppet::Resource::Catalog.new
        @transaction = Puppet::Transaction.new(@config)
    end

    it "should default to the tags specified in the :tags setting" do
        Puppet.expects(:[]).with(:tags).returns("one")
        @transaction.tags.should == %w{one}
    end

    it "should split tags based on ','" do
        Puppet.expects(:[]).with(:tags).returns("one,two")
        @transaction.tags.should == %w{one two}
    end

    it "should use any tags set after creation" do
        Puppet.expects(:[]).with(:tags).never
        @transaction.tags = %w{one two}
        @transaction.tags.should == %w{one two}
    end

    it "should always convert assigned tags to an array" do
        @transaction.tags = "one::two"
        @transaction.tags.should == %w{one::two}
    end
end

describe Puppet::Transaction, " when evaluating" do
    before do
        @catalog = Puppet::Resource::Catalog.new
        @transaction = Puppet::Transaction.new(@catalog)
    end

    it "should use the resource's timeout to set a timeout on each resource" do
        resource = Puppet::Type.type(:exec).new(:name => "/bin/sleep 3", :timeout => 50)
        @catalog.add_resource(resource)

        Timeout.expects(:timeout).with(50.0)
        @transaction.expects(:eval_resource).with(resource).never # because we didn't yield from the above method

        @transaction.evaluate
    end

    it "should log but not propagate timeout errors" do
        resource = Puppet::Type.type(:exec).new(:name => "/bin/sleep 3", :timeout => 50)
        @catalog.add_resource(resource)

        Timeout.expects(:timeout).with(50.0).yields
        @transaction.expects(:eval_resource).with(resource).raises Timeout::Error

        resource.expects(:err)

        lambda { @transaction.evaluate }.should_not raise_error
    end

    it "should record a resource that times out as failed" do
        resource = Puppet::Type.type(:exec).new(:name => "/bin/sleep 3", :timeout => 50)
        @catalog.add_resource(resource)

        Timeout.expects(:timeout).with(50.0).yields
        @transaction.expects(:eval_resource).with(resource).raises Timeout::Error

        @transaction.evaluate

        @transaction.should be_failed(resource)
    end
end
