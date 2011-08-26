require 'spec_helper'

describe Bfire::Location do
  before do
    @api = mock(Bfire::API::Base)
    @resource = mock("api resource")
    @location = Bfire::Location.new("fr-inria", @resource, @api)
  end

  describe "initialization" do
    it "should store the id, resource, and api objects" do
      @location.api.should == @api
      @location.id.should == "fr-inria"
      @location.resource.should == @resource
    end
  end

  describe "::find" do
    before do
      Bfire::API.stub!(:registry).and_return([
        mock(Bfire::API),
        mock(Bfire::API),
        mock(Bfire::API)
      ])
    end
    it "should find the location in one of the registered APIs" do
      Bfire::API.registry[0].should_receive(:find_location).with("fr-inria").
        and_return(nil)
      Bfire::API.registry[1].should_receive(:find_location).with("fr-inria").
        and_return(location = mock(Bfire::Location))
      Bfire::Location.find("fr-inria").should == location
    end

    it "should return nil if it can't find the location in one of the registered APIs" do
      Bfire::API.registry.each{|api|
        api.should_receive(:find_location).with("fr-inria").and_return(nil)
      }
      Bfire::Location.find("fr-inria").should be_nil
    end
  end

  describe "#validate" do
    it "should validate the given template against the api" do
      template = mock(Bfire::Template::Compute)
      @api.should_receive(:validate).with(template).and_return([])
      @location.validate(template).should be_empty
    end
  end
  
  describe "#deploy!" do
    before do
      @template = mock(Bfire::Template::Compute, :to_s => "xyz")
    end
    it "should ask the API to create a new instance based on the template" do
      @api.should_receive(:create_compute).with(@template, @location).
        and_return(compute = mock(Bfire::Compute))
      @location.deploy!(@template).should == compute
    end
    
    it "should raise an error if the api can't create the resource" do
      @api.should_receive(:create_compute).with(@template, @location).
        and_return(nil)
      lambda{
        @location.deploy!(@template)
      }.should raise_error(Bfire::Error, /Can't create compute resource based on template xyz/)
    end
  end
end # describe Bfire::Location