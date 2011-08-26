require 'spec_helper'

describe Bfire::Template::Compute do
  before do
    @group = mock(Bfire::Group, :id => "app".to_sym)
    @location = mock(Bfire::Location, :id => "fr-inria".to_sym)
    @template = Bfire::Template::Compute.new(@group, @location)
  end

  describe "initialization" do
    it "should raise an error if no group is given" do
      lambda{
        Bfire::Template::Compute.new(nil, @location)
      }.should raise_error(ArgumentError, "No group given")
    end
    it "should raise an error if no name is given" do
      lambda{
        Bfire::Template::Compute.new(@group, nil)
      }.should raise_error(ArgumentError, "No location given")
    end
    it "should correctly initialize the object" do
      @template.group.should == @group
      @template.location.should == @location
      @template.config.should == {
        :disks=>[], :nics=>[], :context=>{}, :metrics => []
      }
    end
  end

  describe "methods" do
    it "should set the image to be deployed" do
      @template.deploy "some image name", "some" => "option"
      @template.config[:deploy].should == {
        :name => "some image name",
        :some => "option"
      }
    end
    it "should add a new disk to be attached" do
      @template.attach "some storage name", "some" => "option"
      @template.config[:disks].should == [
        {
          :name => "some storage name",
          :some => "option"
        }
      ]
    end
    it "should add a new nic to be connected" do
      @template.connect "some network name", "some" => "option"
      @template.config[:nics].should == [
        {
          :name => "some network name",
          :some => "option"
        }
      ]
    end
    it "should add a new metric to be monitored" do
      @template.monitor "some metric name", "some" => "option"
      @template.config[:metrics].should == [
        {
          :name => "some metric name",
          :some => "option"
        }
      ]
    end
    it "should set the type of instance to be deployed" do
      @template.type "small"
      @template.config[:type].should == "small"
    end
    it "should add a new contextualisation variable" do
      @template.context "POSTINSTALL", "http://path/to/script"
      @template.config[:context].should == {
        "POSTINSTALL" => "http://path/to/script"
      }
    end
    it "should replace an existing contextualisation variable" do
      @template.context "POSTINSTALL", "http://path/to/script"
      @template.context "POSTINSTALL", "http://path/to/script2"
      @template.config[:context].should == {
        "POSTINSTALL" => "http://path/to/script2"
      }
    end
  end

  describe "validation" do
    it "should validate against the template's location" do
      @location.should_receive(:validate).with(@template).
        and_return([])
      @template.should be_valid
      @template.errors.should be_empty
    end
    it "should not be valid if the location does not validate the template" do
      @location.should_receive(:validate).with(@template).
        and_return(["Bad image"])
      @template.should_not be_valid
      @template.errors.should == ["Bad image"]
    end
  end

  describe "#merge!" do
    it "should take the missing values from the merged template" do
      @template.config[:image] = "image"
      @template.config[:disks] = [
        {:name => "storage1", :some => "property"}
      ]
      @template.config[:nics] = [
        {:name => "network1", :some => "property"}
      ]
      @default_template = Bfire::Template::Compute.new(@group, :default)
      @default_template.config[:image] = "other-image"
      @default_template.config[:disks] = [
        {:name => "storage2", :some => "property"},
        {:name => "storage1", :some => "property2", :other => "property"}
      ]
      @default_template.config[:nics] = [
        {:name => "network1", :some => "property2", :other => "property"},
        {:name => "network2", :some => "property"}
      ]

      @template.merge!(@default_template).should be_a(Bfire::Template::Compute)
      @template.config[:image].should == "image"
      @default_template.config[:disks] = [
        {:name => "storage2", :some => "property"},
        {:name => "storage1", :some => "property", :other => "property"}
      ]
      @default_template.config[:nics] = [
        {:name => "network1", :some => "property", :other => "property"},
        {:name => "network2", :some => "property"}
      ]
    end
  end

  describe "#setup!" do
    before do
      storage_templates = mock("storage_templates")
      network_templates = mock("network_templates")
      @group.stub!(:storage_templates).and_return(storage_templates)
      @group.stub!(:network_templates).and_return(network_templates)
      disks = [{:name => "storage1"}, {:name => "storage2"}]
      @template.config[:disks] = disks
      nics = [{:name => "network1"}, {:name => "network2"}]
      @template.config[:nics] = nics
    end
    it "should raise an error if the template is not valid" do
      @template.should_receive(:valid?).and_return(false)
      @template.should_receive(:errors).and_return(["some error"])
      lambda {
        @template.setup!
      }.should raise_error(Bfire::Error, "Template app/fr-inria: some error")
    end
    it "should setup the required network and storage resources" do
      @template.stub!(:valid?).and_return(true)
      @template.config[:disks].each{|disk|
        @location.should_receive(:find_or_create_storage!).
          with(disk[:name], @group.storage_templates).
          and_return(mock(Bfire::Storage))
      }
      @template.config[:nics].each{|nic|
        @location.should_receive(:find_or_create_network!).
          with(nic[:name], @group.network_templates).
          and_return(mock(Bfire::Network))
      }
      @template.setup!
    end
    it "should raise an error if one of the storage can't be found or created" do
      @template.stub!(:valid?).and_return(true)
      @location.should_receive(:find_or_create_storage!).
        and_raise(Bfire::Error.new("whatever"))
      lambda{
        @template.setup!
      }.should raise_error(Bfire::Error, "whatever")
    end
  end # describe "#setup!"
  
  describe "instances" do
    it "should have zero instances at first" do
      @template.instances.should be_empty
    end
  end # describe "instances"
  
  describe "#deploy!" do
    it "should create a new compute instance based on the template" do
      @location.should_receive(:deploy!).with(@template).and_return(
        compute = mock(Bfire::Compute)
      )
      @template.deploy!.should == compute
      @template.instances.should == [compute]
    end
    it "should not add an instance to the template if the creation failed" do
      @location.should_receive(:deploy!).with(@template).
        and_raise(Bfire::Error.new("failed"))
      lambda{
        @template.deploy!
      }.should raise_error(Bfire::Error, "failed")
      @template.instances.should == []
    end
  end # describe "#deploy!"

  describe "instance_eval" do
    it "should correctly instantiate the template" do
      dsl = <<DSL
type "lite"
deploy "image1"
connect "BonFIRE WAN"
connect "Private LAN", :on => "eth1"
attach "datablock1", :fstype => "ext3"
monitor "some_metric", :command => "/path/to/command", "type" => :numeric
DSL
      @template.instance_eval(dsl)
      @template.config.should == {
        :disks=>[
          {:fstype=>"ext3", :name=>"datablock1"}
        ],
        :nics=>[
          {:name=>"BonFIRE WAN"},
          {:on=>"eth1", :name=>"Private LAN"}
        ],
        :metrics=>[
          {
            :command=>"/path/to/command",
            :type=>:numeric,
            :name=>"some_metric"
          }
        ],
        :context=>{},
        :type=>"lite",
        :deploy=>{:name=>"image1"}
      }
    end
  end

end