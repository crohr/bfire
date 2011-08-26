require 'spec_helper'

describe Bfire::Rule do
  before do
    @group = mock(Bfire::Group, :id => "group".to_sym)
    @rule = Bfire::Rule.new(@group, :initial => 2)
  end
  describe "initialization" do
    it "should have a group reader" do
      @rule.group.should == @group
    end
    it "should setup a default configuration" do
      @rule.config.should == {
        :period=>300, :initial=>2, :range=>1..1
      }
    end
  end
  
  describe "#init!" do
    it "should call scale_up with the inital number of resources wanted" do
      @rule.should_receive(:scale_up).with(2).and_return([
        mock(Bfire::Compute),
        mock(Bfire::Compute)
      ])
      @rule.init!
    end
    it "should raise an error if no resources are created" do
      @rule.should_receive(:scale_up).with(2).and_return([])
      lambda{
        @rule.init!
      }.should raise_error(Bfire::Error, "Failed to create compute resources for group group")
    end
  end
  
  describe "#scale_up" do
    before do
      @group.stub!(:compute_templates).and_return([
        @t1 = mock(Bfire::Template::Compute, 
          :instances => [mock(Bfire::Compute)]
        ),
        @t2 = mock(Bfire::Template::Compute, :instances => [])
      ])
    end
    it "should deploy resources on the templates with the less instances" do
      @t2.should_receive(:deploy!).and_return(mock(Bfire::Compute))
      @rule.scale_up(1)
    end
  end
end # describe Bfire::Rule