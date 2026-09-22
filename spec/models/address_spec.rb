require "rails_helper"

RSpec.describe Address do
  it "is valid with a query" do
    address = described_class.new(query: "Salvador")

    expect(address).to be_valid
  end

  it "is invalid without a query" do
    address = described_class.new(query: nil)

    expect(address).not_to be_valid
  end
end
