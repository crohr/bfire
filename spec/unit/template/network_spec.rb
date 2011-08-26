require 'spec_helper'

describe Bfire::Template::Network do
  it "should be initialized with id and options" do
    template = Bfire::Template::Network.new("id", :some => "option")
    template.id.should == :id
  end
  
  describe "methods" do
    before do
      @template = Bfire::Template::Network.new("id")
    end
    it "should respond to #cidr" do
      @template.should respond_to(:cidr)
      @template.cidr "192.168.0.0/24"
      @template.config[:cidr].should == "192.168.0.0/24"
    end
    it "should respond to #visibility" do
      @template.should respond_to(:visibility)
      @template.visibility :public
      @template.config[:visibility].should == :public
    end
  end
end # describe Bfire::Template::Network