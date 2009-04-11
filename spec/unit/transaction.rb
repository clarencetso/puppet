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

    it "should have a defalut timeout value of 0" do
        Puppet::Type.type(:exec).new(:name => "/bin/sleep 1")[:timeout].should == Float(0)
    end

    it "should timeout with a useful message when the running time of the resource is greater than the 'timeout' parameter" do
        resource = Puppet::Type.type(:exec).new(:name => "/bin/sleep 3", :timeout => "1")
        @catalog.add_resource(resource)

        resource.expects(:err)
        lambda { @transaction.evaluate }.should_not raise_error
    end

    it "should not timeout when the running time of the resource is less than the 'timeout' parameter" do
        resource = Puppet::Type.type(:exec).create(:name => "/bin/sleep 3", :timeout => "5")
        @catalog.add_resource(resource)

        lambda { @transaction.evaluate }.should_not raise_error
    end

    it "should not timeout when the running time of the resource is equal to 0" do
        resource = Puppet::Type.type(:exec).create(:name => "/bin/sleep 3", :timeout => "0")
        @catalog.add_resource(resource)

        lambda { @transaction.evaluate }.should_not raise_error
    end

    it "should not timeout when the running time of the resource is negative" do
        resource = Puppet::Type.type(:exec).create(:name => "/bin/sleep 3", :timeout => "-1")
        @catalog.add_resource(resource)

        lambda { @transaction.evaluate }.should_not raise_error
    end
end
