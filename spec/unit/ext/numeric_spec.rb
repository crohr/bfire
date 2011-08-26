require 'spec_helper'

describe Numeric do
  it "should have access to {K,M,G}B and {K,M,G}iB" do 
    1.GiB.should == 1024**3
    2.5.GB.should == 2.5*1.G*(1.G.to_f/1.GiB)
  end
end # describe Number