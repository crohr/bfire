require 'spec_helper'

describe Bfire::Group do
  before do
    @campaign = mock(Bfire::Campaign)
  end
  
  describe "initialization" do
    it "should raise an error if no campaign is given" do
      lambda{
        Bfire::Group.new("name", nil)
      }.should raise_error(ArgumentError, "No campaign given")
    end
    it "should raise an error if no name is given" do
      lambda{
        Bfire::Group.new("", @campaign)
      }.should raise_error(ArgumentError, "No id given")
    end
    it "should store the given campaign object" do
      group = Bfire::Group.new("name", @campaign)
      group.campaign.should == @campaign
      group.id.should == :name
    end
    it "should include the campaign's network_templates when returing the list of network_templates" do
      @campaign.should_receive(:network_templates).
        and_return(templates = [mock(Bfire::Template::Network)])
      group = Bfire::Group.new("name", @campaign)
      group.network_templates.should == templates
    end
    it "should include the campaign's storage_templates when returing the list of storage_templates" do
      @campaign.should_receive(:storage_templates).
        and_return(templates = [mock(Bfire::Template::Storage)])
      group = Bfire::Group.new("name", @campaign)
      group.storage_templates.should == templates
    end
  end
  
  describe "template building" do
    before do
      @group = Bfire::Group.new("group-name", @campaign)
    end
    
    it "should start with an empty list of compute templates" do
      @group.compute_templates.should be_empty
    end
    
    it "should create a default compute template if it does not exist" do
      Bfire::Location.should_receive(:find).with(:any).
        and_return(mock(Bfire::Location, :id => "fr-inria"))
      authorized_keys = "~/.ssh/authorized_keys"
      File.should_receive(:read).with(File.expand_path(authorized_keys)).
        and_return("ssh-rsa ...")
      @campaign.stub!(:config).
        and_return(:authorized_keys => "~/.ssh/authorized_keys")

      Bfire::Template::Compute.should_receive(:new).
        and_return(template = mock(Bfire::Template::Compute))
      template.should_receive(:context).with(:authorized_keys, "ssh-rsa ...")
      @group.default_template.should == template  
      @group.default_template.should == template
    end
    
    describe "#at" do
      it "should find the template for the given location, and instance_eval the given block on the template" do
        block = proc {}
        Bfire::Location.should_receive(:find).with(
          "fr-inria", {:platform => "bonfire"}
        ).and_return(location=mock(Bfire::Location))
        @group.should_receive(:template).with(location).
          and_return(template = mock(Bfire::Template::Compute))
        template.should_receive(:instance_eval).with(&block)
        @group.at("fr-inria", {:platform => "bonfire"}, &block)
      end
      it "should raise an error if the location can't be found" do
        block = proc {}
        Bfire::Location.should_receive(:find).with("fr-inria", {}).
          and_return(nil)
        lambda{
          @group.at("fr-inria", &block)
        }.should raise_error(Bfire::Error, /Can't find location/)
      end
    end
    
    describe "#depends_on" do
      it "should add a new dependency" do
        block = proc{}
        @group.depends_on(:other_group, &block)
        @group.dependencies.last.should == [:other_group, block]
      end
    end # describe "#depends_on"
    
    describe "#template" do
      before do
        @location = mock(Bfire::Location)
      end
      
      it "should create a new template if there is no existing template linked to this location" do
        Bfire::Template::Compute.should_receive(:new).with(@group, @location).
          and_return(template = mock(Bfire::Template::Compute))
        @group.template(@location).should == template
        @group.compute_templates.last.should == template
      end
      it "should return the template linked to the given location if it already exists" do
        template = mock(Bfire::Template::Compute, :location => @location)
        @group.compute_templates.push template
        @group.template(@location).should == template
      end
    end

    describe "template methods" do
      before do
        @group.stub!(:default_template).and_return(
          @default_template = mock(Bfire::Template::Compute)
        )
      end
      Bfire::Group::TEMPLATE_METHODS.each do |method|
        it "should forward ##{method} to the default template" do
          @default_template.should_receive(method.to_sym)
          @group.send(method.to_sym)
        end
      end
    end
    
    describe "#setup!" do
      it "should merge the default template with the compute templates, and setup each compute template" do
        @group.stub!(:compute_templates).and_return([
          mock(Bfire::Template::Compute),
          mock(Bfire::Template::Compute)
        ])
        @group.stub!(:default_template).
          and_return(default=mock("default template"))
        @group.compute_templates.each do |t|
          t.should_receive(:merge!).with(default)
          t.should_receive(:setup!)
        end
        @group.setup!
      end
    end # describe "#setup!"
    
    describe "#deploy" do
      it "should call init! on the rule" do
        @group.should_receive(:rule).and_return(rule = mock(Bfire::Rule))
        rule.should_receive(:init!)
        @group.deploy!
      end
    end # describe "#deploy"    
  end
  
  
end