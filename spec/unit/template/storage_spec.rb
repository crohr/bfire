require 'spec_helper'

describe Bfire::Template::Storage do
  it "should be initialized with id and options" do
    template = Bfire::Template::Storage.new("id", :some => "option")
    template.id.should == :id
  end
  
  describe "methods" do
    before do
      @template = Bfire::Template::Storage.new("id")
    end
    it "should respond to #size" do
      @template.should respond_to(:size)
      @template.size 2.GB
      @template.config[:size].should == 2.GB
    end
    it "should respond to #visibility" do
      @template.should respond_to(:visibility)
      @template.visibility :public
      @template.config[:visibility].should == :public
    end
    it "should respond to #fstype" do
      @template.should respond_to(:fstype)
      @template.fstype "ext3"
      @template.config[:fstype].should == "ext3"
    end
    it "should respond to #persistent" do
      @template.should respond_to(:persistent)
      @template.persistent
      @template.config[:persistent].should == true
      @template.persistent false
      @template.config[:persistent].should == false
    end
  end
end # describe Bfire::Template::Storage