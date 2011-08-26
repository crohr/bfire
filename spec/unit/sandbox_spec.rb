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
    it "should forward the #use method to the campaign object" do
      @campaign.should_receive(:use).with(:bonfire, :some => "property")
      @sandbox.use(:bonfire, :some => "property")
    end
  end

  describe "#group method" do
    before do
      @sandbox = Bfire::Sandbox.new(@campaign)
      @campaign.stub!(:groups).and_return(@groups = {
        :group1 => mock(Bfire::Group),
        :whatever => mock(Bfire::Group)
      })
    end

    describe "without a block" do
      it "should attempt to find the existing group whose name matches the given name" do
        @sandbox.group("whatever").should == @groups[:whatever]
        @sandbox.group(:whatever).should == @groups[:whatever]
      end
      it "should create a new group if no existing group can be found" do
        Bfire::Group.should_receive(:new).with(:doesnotexist, @campaign, {}).
          and_return(group = mock(Bfire::Group))
        @sandbox.group(:doesnotexist).should == group
      end
    end

    describe "with a block" do
      it "should create a new group if no existing group can be found, and instance_eval the arguments" do
        block = proc{ }
        Bfire::Group.should_receive(:new).with(:doesnotexist, @campaign, {}).
          and_return(group = mock(Bfire::Group))
        group.should_receive(:instance_eval).with(&block)
        @sandbox.group(:doesnotexist, &block)
      end

      it "should return the existing group if group name is already registered, and instance_eval the arguments" do
        block = proc{ }
        @groups[:whatever].should_receive(:instance_eval).with(&block)
        @sandbox.group(:whatever, &block)
      end
    end
  end

  describe "#network method" do
    before do
      @sandbox = Bfire::Sandbox.new(@campaign)
      @campaign.stub!(:network_templates).and_return(@network_templates = {
        :net1 => mock(Bfire::Template::Network),
        :net2 => mock(Bfire::Template::Network)
      })
    end

    describe "without a block" do
      it "should find the existing network template whose id matches the given id" do
        @sandbox.network("net1").should == @network_templates[:net1]
        @sandbox.network(:net1).should == @network_templates[:net1]
      end
      it "should create a new network template if it does not exist" do
        Bfire::Template::Network.should_receive(:new).
          with(:whatever, {}).
          and_return(template = mock(Bfire::Template::Network))
        @sandbox.network(:whatever).should == template
      end
    end # describe "without a block"
    describe "with a block" do
      it "should instance_eval the given block" do
        block = proc{ }
        @network_templates[:net1].should_receive(:instance_eval).with(&block)
        @sandbox.network(:net1, &block)
      end
    end # describe "with a block"

  end # describe "#network method"
  
  describe "#storage method" do
    before do
      @sandbox = Bfire::Sandbox.new(@campaign)
      @campaign.stub!(:storage_templates).and_return(@storage_templates = {
        :storage1 => mock(Bfire::Template::Storage),
        :storage2 => mock(Bfire::Template::Storage)
      })
    end

    describe "without a block" do
      it "should find the existing storage template whose id matches the given id" do
        @sandbox.storage("storage1").should == @storage_templates[:storage1]
        @sandbox.storage(:storage1).should == @storage_templates[:storage1]
      end
      it "should create a new storage template if it does not exist" do
        Bfire::Template::Storage.should_receive(:new).
          with(:whatever, {}).
          and_return(template = mock(Bfire::Template::Storage))
        @sandbox.storage(:whatever).should == template
      end
    end # describe "without a block"
    describe "with a block" do
      it "should instance_eval the given block" do
        block = proc{ }
        @storage_templates[:storage1].
          should_receive(:instance_eval).with(&block)
        @sandbox.storage(:storage1, &block)
      end
    end # describe "with a block"

  end # describe "#network method"

end