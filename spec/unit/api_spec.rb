require 'spec_helper'

describe Bfire::API do
  before do
    Bfire::API.registry.clear
  end
  it "should provide a way to register APIs" do
    Bfire::API.should respond_to(:register)
    Bfire::API.register(api = mock(Bfire::API::Base))
    Bfire::API.registry.should include(api)
  end
  
end # describe Bfire::API