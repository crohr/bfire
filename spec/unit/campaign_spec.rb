require 'spec_helper'

describe Bfire::Campaign do
  before do
    
    @campaign = Bfire::Campaign.new
  end
  
  describe "genrating campaign id" do
    it "should generate an ID if none defined" do
      id = @campaign.id
      id.should =~ /[a-z0-9]{8}/
      @campaign.id.should == id
    end
  end
  
  describe "loading deployment configuration" do    
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
  
  describe "setting up APIs" do
    it "should provide a #use method" do
      @campaign.should respond_to(:use)
    end
    it "should require the API file, and register it with the given options" do
      opts = {:username => "toto", :password => "test"}
      require "bfire/api/bonfire"
      Kernel.should_receive(:require).with("bfire/api/bonfire")
      Bfire::API::Bonfire.should_receive(:new).with(@campaign, opts).
        and_return(api = mock(Bfire::API::Bonfire))
      Bfire::API.should_receive(:register).with(api)
      @campaign.use :bonfire, opts
    end
  end
  
  describe "setting configuration variables" do
    it "should have a #config method" do
      @campaign.config.should == {
        :name=>"Bfire Campaign", 
        :description=>"Bfire Campaign Description"
      }
    end
    it "should respond to #set" do
      @campaign.should respond_to(:set)
    end
    it "should set the property" do
      @campaign.set "key", "value"
      @campaign.config[:key].should == "value"
    end
  end
  
  describe "groups, network_templates, storage_templates" do
    it "should start with an empty hash of groups" do
      @campaign.groups.should == {}
    end
    it "should start with an empty hash of network_templates" do
      @campaign.network_templates.should == {}
    end
    it "should start with an empty hash of storage_templates" do
      @campaign.storage_templates.should == {}
    end
  end
  
  describe "setting up required resources" do
    it "should setup each group" do
      Bfire::API.registry.each{|api| api.should_receive(:setup!) }
      @campaign.groups.each{|group|  group.should_receive(:setup!) }
      @campaign.setup!
    end
  end
  
  describe "building the directed adjacency graph" do
    it "should raise an error if there are cyclic dependencies between groups" do
      group1 = mock(Bfire::Group, :dependencies => [[:group2, proc{}]])
      group2 = mock(Bfire::Group, :dependencies => [[:group1, proc{}]])
      @campaign.groups[:group1] = group1
      @campaign.groups[:group2] = group2
      lambda{
        @campaign.dag
      }.should raise_error(Bfire::Error, "The group dependency graph is not acyclic!")
    end
    it "should return the dag if there are no cyclic dependencies" do
      group1 = mock(Bfire::Group, :dependencies => [])
      group2 = mock(Bfire::Group, :dependencies => [[:group1, proc{}]])
      @campaign.groups[:group1] = group1
      @campaign.groups[:group2] = group2
      @campaign.dag.to_a.should == [:group1, :group2]
    end
  end
  
  describe "#deploy!" do
    it "should build the dag" do
      @campaign.should_receive(:dag).and_return(dag = mock("dag"))
      dag.should_receive(:topsort_iterator).
        and_return(iterator = mock("topsort iterator"))
      @campaign.should_receive(:in_order).with(iterator)      
      @campaign.deploy!
    end
  end # describe "#deploy!"
  
  describe "#in_order" do
    it "should" do
      
    end
  end
end