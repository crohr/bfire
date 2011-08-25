require 'spec_helper'

describe Bfire::Campaign do
  it "should initialize the campaign" do
    campaign = Bfire::Campaign.new
  end
  
  describe "loading deployment configuration" do
    before do
      @campaign = Bfire::Campaign.new
    end
    
    it "should load the given URI" do
      Kernel.should_receive(:open).with("http://path/to/file").
        and_return(StringIO.new("dsl content"))
      @campaign.should_receive(:sandbox).
        and_return(sandbox = mock(Bfire::Sandbox))
      sandbox.should_receive(:load).
        with("dsl content").
        and_return(true)
      @campaign.load("http://path/to/file").should be_true
    end
  end
  # 
  # it "should describe the thing" do
  #   campaign = Bfire::Campaign.new
  #   campaign.load(String || URI)
  #   p campaign.groups
  #   campaign.groups.each do |group|
  #     group.templates.each do |template|
  #     end
  #   end
  #   
  #   campaign.start
  # end
  
  
  
end