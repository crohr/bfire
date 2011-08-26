require 'spec_helper'

describe "Integration tests for campaign" do
  before do
    Bfire::API.registry.clear
    @campaign = Bfire::Campaign.new
  end
  
  if ENV['LIVE'] && ENV['LIVE'] == "1"
    it "does something" do
      dsl = <<DSL
use :bonfire, :configuration_file => "~/.restfully/api.bonfire-project.eu"

group :app do
  at "de-hlrs"
  type "lite"
  deploy "BonFIRE Debian Squeeze 2G v2"
  connect "BonFIRE WAN"
end
DSL
      Bfire.logger.level = Logger::DEBUG
      @campaign.load(StringIO.new(dsl))
      @campaign.start!
    end
  end
  
end