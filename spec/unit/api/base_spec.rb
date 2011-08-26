require 'spec_helper'

describe Bfire::API::Base do
  before do
    @campaign = mock(Bfire::Campaign)
    @api = Bfire::API::Base.new(@campaign, :some => "property")
  end
  
  it "should store the options given at intialization in a :config attribute" do
    @api.config.should == {:some => "property"}
    @api.campaign.should == @campaign
  end
  
  it "should provide a #find_location method that returns nil by default" do
    @api.find_location("fr-inria").should be_nil
  end
  it "should provide a #find_campaign method that returns nil by default" do
    @api.find_campaign("some-id").should be_nil
  end
  
  it "should provide a #validate method to validate a template, that returns an empty list of errors by default" do
    template = mock(Bfire::Template::Compute)
    @api.validate(template).should be_empty
  end
  
  # use Bfire::API::Bonfire, :username => '', :password => ''
  # use Bfire::API, :username => '', :password => ''
end # describe Bfire::API