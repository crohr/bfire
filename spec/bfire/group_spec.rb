require 'spec_helper'

describe Bfire::Group do
  before do
    @campaign = mock(Bfire::Campaign)
  end
  
  describe "initialization" do
    it "should raise an error if no campaign is given" do
      lambda{
        Bfire::Group.new(nil, "name")
      }.should raise_error(ArgumentError, "No campaign given")
    end
    it "should raise an error if no name is given" do
      lambda{
        Bfire::Group.new(@campaign, "")
      }.should raise_error(ArgumentError, "No name given")
    end
    it "should store the given campaign object" do
      group = Bfire::Group.new(@campaign, "name")
      group.campaign.should == @campaign
      group.name.should == :name
    end
  end
  
  describe "template building" do
    before do
      @group = Bfire::Group.new(@campaign, "group-name")
    end
    
    it "should start with an empty list of templates" do
      @group.templates.should be_empty
    end
    
    it "should create a default template if it does not exist" do
      Bfire::Template.should_receive(:new).
        and_return(template = mock(Bfire::Template))
      @group.default_template.should == template  
      @group.default_template.should == template
    end
    
    describe "#at" do
      it "should find the template for the given location, and instance_eval the given block on the template" do
        block = proc {}
        @group.should_receive(:template).with("fr-inria").
          and_return(template = mock(Bfire::Template))
        template.should_receive(:instance_eval).with(&block)
        @group.at("fr-inria", &block)
      end
    end
    
    describe "#template" do
      before do
        @location = mock(Bfire::Location)
      end
      
      it "should raise an error if the given location can't be found" do
        @campaign.should_receive(:fetch_location).with("doesnotexist").
          and_raise(Bfire::Error.new("Can't find location"))
        lambda{
          @group.template("doesnotexist")
        }.should raise_error(Bfire::Error, "Can't find location")
      end
      it "should create a new template if there is no existing template linked to this location" do
        @campaign.should_receive(:fetch_location).with("fr-inria").
          and_return(@location)
        Bfire::Template.should_receive(:new).with(@group, @location).
          and_return(template = mock(Bfire::Template))
        @group.template("fr-inria").should == template
        @group.templates.last.should == template
      end
      it "should return the template linked to the given location if it already exists" do
        @campaign.should_receive(:fetch_location).with("fr-inria").
          and_return(@location)
        template = mock(Bfire::Template, :location => @location)
        @group.templates.push template
        @group.template("fr-inria").should == template
      end
    end

    describe "template methods" do
      before do
        @group.stub!(:default_template).and_return(
          @default_template = mock(Bfire::Template)
        )
      end
      Bfire::Group::TEMPLATE_METHODS.each do |method|
        it "should forward ##{method} to the default template" do
          @default_template.should_receive(method.to_sym)
          @group.send(method.to_sym)
        end
      end
    end
    
      describe "instance_eval" do
        it "should correctly instantiate the template" do
          @campaign.should_receive(:fetch_location).with("fr-inria").
            and_return(mock(Bfire::Location))
          @campaign.should_receive(:fetch_location).with("de-hlrs").
            and_return(mock(Bfire::Location))
          dsl = <<DSL
type "lite"
deploy "image1"
connect "BonFIRE WAN"
at "fr-inria"
at "de-hlrs" do
  type "small"
  deploy "image2"
  connect "Public WAN"
end
monitor "some_metric"
DSL
          @group.instance_eval(dsl)
          @group.templates.length.should == 2
          @group.default_template.config.should == {
            :disks=>[], 
            :nics=>[{:name=>"BonFIRE WAN"}], 
            :metrics=>[{:name=>"some_metric"}], 
            :context=>{}, 
            :type=>"lite", 
            :deploy=>{:name=>"image1"}
          }
        end
      end
    
  end
  
  
end