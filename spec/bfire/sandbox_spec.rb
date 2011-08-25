require 'spec_helper'

describe Bfire::Sandbox do
  before do
    @campaign = mock(Bfire::Campaign)
  end
  it "should store the campaign object given on initialization" do
    sandbox = Bfire::Sandbox.new(@campaign)
    sandbox.campaign.should == @campaign
  end
  
  describe "initialized sandbox" do
    before do
      @sandbox = Bfire::Sandbox.new(@campaign)
    end
    it "should forward the #set method to the campaign object" do
      @campaign.should_receive(:set).with(:whatever, "value")
      @sandbox.set(:whatever, "value")
    end
  end
  
  describe "#group method" do
    before do
      @sandbox = Bfire::Sandbox.new(@campaign)
      @campaign.stub!(:groups).and_return(@groups = [
        mock(Bfire::Group, :name => :group1),
        mock(Bfire::Group, :name => :whatever)
      ])
    end
    
    describe "without a block" do
      it "should attempt to find the existing group whose name matches the given name" do
        @sandbox.group("whatever").should == @groups[1]
        @sandbox.group(:whatever).should == @groups[1]
      end
      it "should return nil if no group can be found for the given name" do
        @sandbox.group(:doesnotexist).should be_nil
      end
    end
    
    describe "with a block" do
      it "should create a new group if no existing group can be found, and instance_eval the arguments" do
        block = proc{ }
        Bfire::Group.should_receive(:new).with(@campaign, :doesnotexist, {}).
          and_return(group = mock(Bfire::Group))
        @campaign.groups.should_receive(:push).with(group)
        group.should_receive(:instance_eval).with(&block)
        @sandbox.group(:doesnotexist, &block)
      end
      
      it "should return the existing group if group name is already registered, and instance_eval the arguments" do
        block = proc{ }
        @groups[1].should_receive(:instance_eval).with(&block)
        @sandbox.group(:whatever, &block)
      end
    end
  end
end