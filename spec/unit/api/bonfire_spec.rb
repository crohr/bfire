require 'spec_helper'
require 'bfire/api/bonfire'

describe Bfire::API::Bonfire do
  before do
    @campaign = mock(Bfire::Campaign)
    Bfire::API.registry.clear
    @api = Bfire::API::Bonfire.new(@campaign)
    @session = mock(Restfully::Session)
  end
  it "should be able to register it in the API registry" do
    Bfire::API.register @api
    Bfire::API.registry.should include(@api)
  end

  describe "#find_location" do
    before do
      @api.stub!(:locations).and_return([
        @resource = {'name' => 'fr-inria'}
      ])
    end
    it "should find the location" do
      Bfire::Location.should_receive(:new).with(:"fr-inria", @resource, @api).
        and_return(location = mock(Bfire::Location))
      @api.find_location("fr-inria").should == location
    end
    it "should return nil if no location can be found" do
      @api.find_location("doesnotexist").should be_nil
    end
  end

  describe "#validate" do
    before do
      @template = mock(Bfire::Template::Compute,
        :config => {
          :deploy => {:name => "BonFIRE Squeeze v2"},
          :disks => [
            {:name => "datablock1"}
          ],
          :nics => [
            {:name => "BonFIRE WAN"},
            {:name => "Public Network"}
          ],
          :type => "lite"
        },
        :group => mock(Bfire::Group),
        :location => mock(Bfire::Location)
      )
    end
    
    it "should be valid if template is complete" do
      pending
      @api.validate(@template).should be_empty
    end

    it "should return false if the image to deploy does not exist" do
      pending
      @template.config.delete(:deploy)
      @api.validate(@template).should include("Image '' does not exist")
    end


  end
end # describe Bfire::API::Bonfire