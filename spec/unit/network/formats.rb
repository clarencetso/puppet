#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'

require 'puppet/network/formats'

class JsonTest
    attr_accessor :string
    def ==(other)
        string == other.string
    end

    def self.from_json(data)
        new(data)
    end

    def initialize(string)
        @string = string
    end

    def to_json(*args)
        {
            'json_class' => self.class.name,
            'data' => @string
        }.to_json(*args)
    end
end

describe "Puppet Network Format" do
    it "should include a yaml format" do
        Puppet::Network::FormatHandler.format(:yaml).should_not be_nil
    end

    describe "yaml" do
        before do
            @yaml = Puppet::Network::FormatHandler.format(:yaml)
        end

        it "should have its mime type set to text/yaml" do
            @yaml.mime.should == "text/yaml"
        end

        it "should be supported on Strings" do
            @yaml.should be_supported(String)
        end

        it "should render by calling 'to_yaml' on the instance" do
            instance = mock 'instance'
            instance.expects(:to_yaml).returns "foo"
            @yaml.render(instance).should == "foo"
        end

        it "should fixup generated yaml on render" do
            instance = mock 'instance', :to_yaml => "foo"

            @yaml.expects(:fixup).with("foo").returns "bar"

            @yaml.render(instance).should == "bar"
        end

        it "should render multiple instances by calling 'to_yaml' on the array" do
            instances = [mock('instance')]
            instances.expects(:to_yaml).returns "foo"
            @yaml.render_multiple(instances).should == "foo"
        end

        it "should fixup generated yaml on render" do
            instances = [mock('instance')]
            instances.stubs(:to_yaml).returns "foo"

            @yaml.expects(:fixup).with("foo").returns "bar"

            @yaml.render(instances).should == "bar"
        end

        it "should intern by calling 'YAML.load'" do
            text = "foo"
            YAML.expects(:load).with("foo").returns "bar"
            @yaml.intern(String, text).should == "bar"
        end

        it "should intern multiples by calling 'YAML.load'" do
            text = "foo"
            YAML.expects(:load).with("foo").returns "bar"
            @yaml.intern_multiple(String, text).should == "bar"
        end

        it "should fixup incorrect yaml to correct" do
            @yaml.fixup("&id004 !ruby/object:Puppet::Relationship ?").should == "? &id004 !ruby/object:Puppet::Relationship"
        end
    end

    it "should include a marshal format" do
        Puppet::Network::FormatHandler.format(:marshal).should_not be_nil
    end

    describe "marshal" do
        before do
            @marshal = Puppet::Network::FormatHandler.format(:marshal)
        end

        it "should have its mime type set to text/marshal" do
            Puppet::Network::FormatHandler.format(:marshal).mime.should == "text/marshal"
        end

        it "should be supported on Strings" do
            @marshal.should be_supported(String)
        end

        it "should render by calling 'Marshal.dump' on the instance" do
            instance = mock 'instance'
            Marshal.expects(:dump).with(instance).returns "foo"
            @marshal.render(instance).should == "foo"
        end

        it "should render multiple instances by calling 'to_marshal' on the array" do
            instances = [mock('instance')]

            Marshal.expects(:dump).with(instances).returns "foo"
            @marshal.render_multiple(instances).should == "foo"
        end

        it "should intern by calling 'Marshal.load'" do
            text = "foo"
            Marshal.expects(:load).with("foo").returns "bar"
            @marshal.intern(String, text).should == "bar"
        end

        it "should intern multiples by calling 'Marshal.load'" do
            text = "foo"
            Marshal.expects(:load).with("foo").returns "bar"
            @marshal.intern_multiple(String, text).should == "bar"
        end
    end

    describe "plaintext" do
        before do
            @text = Puppet::Network::FormatHandler.format(:s)
        end

        it "should have its mimetype set to text/plain" do
            @text.mime.should == "text/plain"
        end
    end

    describe Puppet::Network::FormatHandler.format(:raw) do
        before do
            @format = Puppet::Network::FormatHandler.format(:raw)
        end

        it "should exist" do
            @format.should_not be_nil
        end

        it "should have its mimetype set to application/x-raw" do
            @format.mime.should == "application/x-raw"
        end

        it "should always be supported" do
            @format.should be_supported(String)
        end

        it "should fail if its multiple_render method is used" do
            lambda { @format.render_multiple("foo") }.should raise_error(NotImplementedError)
        end

        it "should fail if its multiple_intern method is used" do
            lambda { @format.intern_multiple(String, "foo") }.should raise_error(NotImplementedError)
        end

        it "should have a weight of 1" do
            @format.weight.should == 1
        end
    end

    it "should include a json format" do
        Puppet::Network::FormatHandler.format(:json).should_not be_nil
    end

    describe "json" do
        confine "Missing 'json' library" => Puppet.features.json?

        before do
            @json = Puppet::Network::FormatHandler.format(:json)
        end

        it "should have its mime type set to text/json" do
            Puppet::Network::FormatHandler.format(:json).mime.should == "text/json"
        end

        it "should require the :render_method" do
            Puppet::Network::FormatHandler.format(:json).required_methods.should be_include(:render_method)
        end

        it "should require the :intern_method" do
            Puppet::Network::FormatHandler.format(:json).required_methods.should be_include(:intern_method)
        end

        it "should have a weight of 10" do
            @json.weight.should == 10
        end

        describe "when supported" do
            it "should render by calling 'to_json' on the instance" do
                instance = JsonTest.new("foo")
                instance.expects(:to_json).returns "foo"
                @json.render(instance).should == "foo"
            end

            it "should render multiple instances by calling 'to_json' on the array" do
                instances = [mock('instance')]

                instances.expects(:to_json).returns "foo"

                @json.render_multiple(instances).should == "foo"
            end

            it "should intern by calling 'JSON.parse' on the text and then using from_json to convert the data into an instance" do
                text = "foo"
                JSON.expects(:parse).with("foo").returns("json_class" => "JsonTest", "data" => "foo")
                JsonTest.expects(:from_json).with("foo").returns "parsed_json"
                @json.intern(JsonTest, text).should == "parsed_json"
            end

            it "should intern by calling 'JSON.parse' on the text and then using from_json to convert the actual into an instance if the json has no class/data separation" do
                text = "foo"
                JSON.expects(:parse).with("foo").returns("foo")
                JsonTest.expects(:from_json).with("foo").returns "parsed_json"
                @json.intern(JsonTest, text).should == "parsed_json"
            end

            it "should intern multiples by parsing the text and using 'class.intern' on each resulting data structure" do
                text = "foo"
                JSON.expects(:parse).with("foo").returns ["bar", "baz"]
                JsonTest.expects(:from_json).with("bar").returns "BAR"
                JsonTest.expects(:from_json).with("baz").returns "BAZ"
                @json.intern_multiple(JsonTest, text).should == %w{BAR BAZ}
            end
        end
    end
end
