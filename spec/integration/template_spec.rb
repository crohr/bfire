require 'spec_helper'
require 'bfire/api/bonfire'

describe "Integration tests for templates" do
  before do
    Bfire::API.registry.clear
    @campaign = mock(Bfire::Campaign, :config => {})
    @api = mock(Bfire::API::Bonfire)
    Bfire::API.register @api

    @group = Bfire::Group.new("name", @campaign)
    @location1 = Bfire::Location.new("fr-inria", mock("api resource"), @api)
    @location2 = Bfire::Location.new("de-hlrs", mock("api resource"), @api)

    @api.should_receive(:find_location).with(:any).and_return(@location1)
    [@location1, @location2].each do |location|
      @api.should_receive(:find_location).with(location.id).
        and_return(location)
    end
  end

  it "does something" do
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
    @group.compute_templates.length.should == 2
  end

end