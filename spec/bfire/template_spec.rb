require 'spec_helper'

describe Bfire::Template do
  before do
    @group = mock(Bfire::Group)
    @location = mock(Bfire::Location)
  end
  
  describe "initialization" do
    it "should raise an error if no group is given" do
      lambda{
        Bfire::Template.new(nil, @location)
      }.should raise_error(ArgumentError, "No group given")
    end
    it "should raise an error if no name is given" do
      lambda{
        Bfire::Template.new(@group, nil)
      }.should raise_error(ArgumentError, "No location given")
    end    
    it "should correctly initialize the object" do
      template = Bfire::Template.new(@group, @location)
      template.group.should == @group
      template.location.should == @location
      template.config.should == {:disks=>[], :nics=>[], :context=>{}, :metrics => []}
    end
  end
  
  describe "methods" do
    before do
      @template = Bfire::Template.new(@group, @location)
    end
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
    before do
      @template = Bfire::Template.new(@group, @location)
    end
    it "should validate against the template's location" do
      @location.should_receive(:validate).with(@template).
        and_return(true)
      @template.should be_valid
    end
    it "should not be valid if the location does not validate the template" do
      @location.should_receive(:validate).with(@template).
        and_return(false)
      @template.should_not be_valid
    end
  end
  
  describe "instance_eval" do
    before do
      @template = Bfire::Template.new(@group, @location)
    end
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