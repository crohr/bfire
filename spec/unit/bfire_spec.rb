require 'spec_helper'

describe Bfire do
  it "should create a default logger" do
    logger1 = Bfire.logger
    logger2 = Bfire.logger
    logger1.should be_a(Logger)
    logger1.should == logger2
    Bfire.logger.level.should == Logger::INFO
  end
  
  it "should allow to overwrite the default logger" do
    logger = mock(Logger)
    Bfire.logger = logger
    Bfire.logger.should == logger
  end
  
  after do
    Bfire.instance_variable_set "@logger", nil
  end
end # describe Bfire