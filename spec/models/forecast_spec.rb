require "rails_helper"

RSpec.describe Forecast do
  let(:address) do
    Address.new(query: "Salvador")
  end

  let(:expires_at) do
    Time.zone.parse("2026-09-21 22:00:00")
  end

  let(:forecast) do
    described_class.new(
      address: address,
      dates: [
        "2026-09-21",
        "2026-09-22",
        "2026-09-23"
      ],
      maximum_temperatures: [
        29.5,
        30.0,
        28.7
      ],
      minimum_temperatures: [
        23.1,
        22.8,
        22.5
      ],
      expires_at: expires_at,
      from_cache: false
    )
  end

  describe "#days" do
    it "combines dates with maximum and minimum temperatures" do
      expect(forecast.days).to eq(
        [
          {
            date: "2026-09-21",
            maximum_temperature: 29.5,
            minimum_temperature: 23.1
          },
          {
            date: "2026-09-22",
            maximum_temperature: 30.0,
            minimum_temperature: 22.8
          },
          {
            date: "2026-09-23",
            maximum_temperature: 28.7,
            minimum_temperature: 22.5
          }
        ]
      )
    end
  end

  describe "#as_json" do
    it "returns the address, days, and expiration time" do
      expect(forecast.as_json).to eq(
        {
          address: "Salvador",
          days: forecast.days,
          expires_at: expires_at,
          from_cache: false
        }
      )
    end
  end
end
