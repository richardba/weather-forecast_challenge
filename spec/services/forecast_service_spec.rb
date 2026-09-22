require "rails_helper"

RSpec.describe ForecastService do
  let(:cache) do
    ActiveSupport::Cache::MemoryStore.new
  end

  let(:address_service) do
    instance_double(AddressService)
  end

  let(:service) do
    described_class.new(
      address_service: address_service,
      cache: cache
    )
  end

  let(:address) do
    Address.new(query: "Salvador")
  end

  let(:location) do
    {
      "lat" => "-12.9714",
      "lon" => "-38.5014"
    }
  end

  let(:forecast_data) do
    {
      "daily" => {
        "time" => [
          "2026-09-21",
          "2026-09-22",
          "2026-09-23"
        ],
        "temperature_2m_max" => [
          29.5,
          30.0,
          28.7
        ],
        "temperature_2m_min" => [
          23.1,
          22.8,
          22.5
        ]
      }
    }
  end

  def successful_response(body)
    response = Net::HTTPOK.new(
      "1.1",
      "200",
      "OK"
    )

    response.instance_variable_set(:@body, body)
    response.instance_variable_set(:@read, true)

    response
  end

  def error_response
    response = Net::HTTPBadGateway.new(
      "1.1",
      "502",
      "Bad Gateway"
    )

    response.instance_variable_set(:@body, "Bad Gateway")
    response.instance_variable_set(:@read, true)

    response
  end

  describe "#call" do
    before do
      allow(address_service)
        .to receive(:call)
        .with(address)
        .and_return([location])
    end

    it "returns a forecast" do
      allow(service)
        .to receive(:request)
        .with(
          latitude: location["lat"],
          longitude: location["lon"]
        )
        .and_return(
          successful_response(forecast_data.to_json)
        )

      forecast = service.call(address)

      expect(forecast).to be_a(Forecast)
      expect(forecast.address).to eq(address)

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

    it "marks the first response as not from cache" do
      allow(service)
        .to receive(:request)
        .and_return(
          successful_response(forecast_data.to_json)
        )

      forecast = service.call(address)

      expect(forecast.from_cache).to be(false)
    end

    it "uses the cached forecast on subsequent calls" do
      allow(service)
        .to receive(:request)
        .and_return(
          successful_response(forecast_data.to_json)
        )

      first_forecast = service.call(address)
      second_forecast = service.call(address)

      expect(service)
        .to have_received(:request)
        .once

      expect(first_forecast.from_cache).to be(false)
      expect(second_forecast.from_cache).to be(true)
    end

    it "keeps the same expiration time when using cached data" do
      allow(service)
        .to receive(:request)
        .and_return(
          successful_response(forecast_data.to_json)
        )

      first_forecast = service.call(address)
      second_forecast = service.call(address)

      expect(second_forecast.expires_at)
        .to eq(first_forecast.expires_at)
    end

    it "raises InvalidAddress when the address is invalid" do
      invalid_address = Address.new(query: nil)

      expect {
        service.call(invalid_address)
      }.to raise_error(
        ForecastService::InvalidAddress,
        /Query can't be blank/
      )

      expect(address_service)
        .not_to have_received(:call)
    end

    it "raises AddressNotFound when no location is found" do
      allow(address_service)
        .to receive(:call)
        .with(address)
        .and_return([])

      expect {
        service.call(address)
      }.to raise_error(
        ForecastService::AddressNotFound,
        "Address not found"
      )
    end

    it "raises an error when the address service returns an invalid response" do
      allow(address_service)
        .to receive(:call)
        .with(address)
        .and_return("invalid")

      expect {
        service.call(address)
      }.to raise_error(
        ForecastService::Error,
        "Unexpected response from address service"
      )
    end

    it "raises an error when the location has no coordinates" do
      allow(address_service)
        .to receive(:call)
        .with(address)
        .and_return(
          [
            {
              "display_name" => "Salvador"
            }
          ]
        )

      expect {
        service.call(address)
      }.to raise_error(
        ForecastService::Error,
        "Invalid location returned by address service"
      )
    end

    it "raises an error when Open-Meteo returns an unsuccessful response" do
      allow(service)
        .to receive(:request)
        .and_return(error_response)

      expect {
        service.call(address)
      }.to raise_error(
        ForecastService::Error,
        "Open-Meteo request failed with HTTP 502"
      )
    end

    it "raises an error when Open-Meteo returns invalid JSON" do
      allow(service)
        .to receive(:request)
        .and_return(
          successful_response("not valid json")
        )

      expect {
        service.call(address)
      }.to raise_error(
        ForecastService::Error,
        /Invalid JSON response from Open-Meteo/
      )
    end

    it "raises an error when daily forecast data is not a hash" do
      data = {
        "daily" => "invalid"
      }

      allow(service)
        .to receive(:request)
        .and_return(
          successful_response(data.to_json)
        )

      expect {
        service.call(address)
      }.to raise_error(
        ForecastService::Error,
        "Invalid daily forecast data"
      )
    end

    it "raises an error when daily forecast arrays have inconsistent lengths" do
      data = {
        "daily" => {
          "time" => [
            "2026-09-21",
            "2026-09-22"
          ],
          "temperature_2m_max" => [
            29.5
          ],
          "temperature_2m_min" => [
            23.1,
            22.8
          ]
        }
      }

      allow(service)
        .to receive(:request)
        .and_return(
          successful_response(data.to_json)
        )

      expect {
        service.call(address)
      }.to raise_error(
        ForecastService::Error,
        "Daily forecast arrays have inconsistent lengths"
      )
    end

    it "raises an error when daily forecast data is empty" do
      data = {
        "daily" => {
          "time" => [],
          "temperature_2m_max" => [],
          "temperature_2m_min" => []
        }
      }

      allow(service)
        .to receive(:request)
        .and_return(
          successful_response(data.to_json)
        )

      expect {
        service.call(address)
      }.to raise_error(
        ForecastService::Error,
        "Daily forecast data is empty"
      )
    end

    it "wraps network errors" do
      allow(service)
        .to receive(:request)
        .and_raise(
          Timeout::Error,
          "execution expired"
        )

      expect {
        service.call(address)
      }.to raise_error(
        ForecastService::Error,
        /Open-Meteo request failed/
      )
    end
  end
end
