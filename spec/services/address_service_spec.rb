require "rails_helper"

RSpec.describe AddressService do
  let(:cache) do
    ActiveSupport::Cache::MemoryStore.new
  end

  let(:service) do
    described_class.new(
      user_agent: "weather-app-test",
      cache: cache
    )
  end

  let(:address) do
    Address.new(query: "Salvador")
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

  def error_response(code = "500")
    response = Net::HTTPInternalServerError.new(
      "1.1",
      code,
      "Internal Server Error"
    )

    response.instance_variable_set(:@body, "Server error")
    response.instance_variable_set(:@read, true)

    response
  end

  describe "#call" do
    it "returns locations from Nominatim" do
      body = [
        {
          "lat" => "-12.9714",
          "lon" => "-38.5014",
          "display_name" => "Salvador, Bahia, Brazil"
        }
      ].to_json

      allow(service)
        .to receive(:request)
        .with(address)
        .and_return(successful_response(body))

      result = service.call(address)

      expect(result).to eq(
        [
          {
            "lat" => "-12.9714",
            "lon" => "-38.5014",
            "display_name" => "Salvador, Bahia, Brazil"
          }
        ]
      )
    end

    it "caches the response" do
      body = [
        {
          "lat" => "-12.9714",
          "lon" => "-38.5014"
        }
      ].to_json

      allow(service)
        .to receive(:request)
        .with(address)
        .and_return(successful_response(body))

      service.call(address)
      service.call(address)

      expect(service)
        .to have_received(:request)
        .once
    end

    it "uses the same cache entry for normalized addresses" do
      first_address = Address.new(
        query: "Salvador"
      )

      second_address = Address.new(
        query: "  SALVADOR  "
      )

      body = [
        {
          "lat" => "-12.9714",
          "lon" => "-38.5014"
        }
      ].to_json

      allow(service)
        .to receive(:request)
        .and_return(successful_response(body))

      first_result = service.call(first_address)
      second_result = service.call(second_address)

      expect(first_result).to eq(second_result)

      expect(service)
        .to have_received(:request)
        .once
    end

    it "raises an error when Nominatim returns an unsuccessful response" do
      allow(service)
        .to receive(:request)
        .with(address)
        .and_return(error_response)

      expect {
        service.call(address)
      }.to raise_error(
        AddressService::Error,
        "Nominatim request failed with HTTP 500"
      )
    end

    it "raises an error when Nominatim returns invalid JSON" do
      allow(service)
        .to receive(:request)
        .with(address)
        .and_return(
          successful_response("not valid json")
        )

      expect {
        service.call(address)
      }.to raise_error(
        AddressService::Error,
        /Invalid JSON response from Nominatim/
      )
    end

    it "raises an error when Nominatim returns an unexpected response" do
      body = {
        "lat" => "-12.9714",
        "lon" => "-38.5014"
      }.to_json

      allow(service)
        .to receive(:request)
        .with(address)
        .and_return(successful_response(body))

      expect {
        service.call(address)
      }.to raise_error(
        AddressService::Error,
        "Unexpected response from Nominatim"
      )
    end

    it "wraps network errors" do
      allow(service)
        .to receive(:request)
        .with(address)
        .and_raise(Timeout::Error, "execution expired")

      expect {
        service.call(address)
      }.to raise_error(
        AddressService::Error,
        /Nominatim request failed/
      )
    end
  end
end
