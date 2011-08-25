require 'webmock/rspec'
require 'bfire'

def fixture(filename)
  File.read(File.join(File.dirname(__FILE__), "fixtures", filename))
end

RSpec.configure do |config|

  config.before(:each) do
  end

  config.mock_with :rspec

end
