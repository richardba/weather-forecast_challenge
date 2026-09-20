require "net/http"
require "uri"
require "json"
require "openssl"

class ForecastService
  class Error < StandardError; end
  class InvalidAddress < Error; end
  class AddressNotFound < Error; end

  ENDPOINT = URI("https://api.open-meteo.com/v1/forecast").freeze
  
  CACHE_EXPIRATION = 30.minutes
  
  NETWORK_ERRORS = [
    Timeout::Error,
    SocketError,
    EOFError,
    Errno::ECONNREFUSED,
    Errno::ECONNRESET,
    Errno::ETIMEDOUT,
    OpenSSL::SSL::SSLError
  ].freeze

  def initialize(address_service:, cache: Rails.cache)
    @address_service = address_service
    @cache = cache
  end

  def call(address)
    validate_address!(address)

    location = find_location(address)

    from_cache = true

    cached_forecast = @cache.fetch(
      cache_key(location),
      expires_in: CACHE_EXPIRATION
    ) do
      from_cache = false
      {
        "data" => fetch_forecast(location),
        "expires_at" => CACHE_EXPIRATION.from_now.iso8601
      }
    end

    build_forecast(
      address,
      cached_forecast.fetch("data"),
      expires_at: cached_forecast.fetch("expires_at"),
      from_cache: from_cache
    )
  end

  private

  def cache_key(location)
    latitude = location.fetch("lat")
    longitude = location.fetch("lon")

    "forecast_service:open_meteo:#{latitude}:#{longitude}"
  end

  def validate_address!(address)
    unless address.is_a?(Address)
      raise ArgumentError, "address must be an Address"
    end

    return if address.valid?

    raise InvalidAddress, address.errors.full_messages.join(", ")
  end

  def find_location(address)
    locations = @address_service.call(address)

    unless locations.is_a?(Array)
      raise Error, "Unexpected response from address service"
    end

    raise AddressNotFound, "Address not found" if locations.empty?

    location = locations.first

    unless location.is_a?(Hash) &&
           location["lat"].present? &&
           location["lon"].present?
      raise Error, "Invalid location returned by address service"
    end

    location
  end

  def request(latitude:, longitude:)
    uri = ENDPOINT.dup

    uri.query = URI.encode_www_form(
      latitude: latitude,
      longitude: longitude,
      daily: "temperature_2m_max,temperature_2m_min",
      timezone: "auto",
      forecast_days: 3
    )

    http_request = Net::HTTP::Get.new(uri)
    http_request["Accept"] = "application/json"

    Net::HTTP.start(
      uri.hostname,
      uri.port,
      use_ssl: true,
      open_timeout: 5,
      read_timeout: 10
    ) do |http|
      http.request(http_request)
    end
  end

  def build_forecast(address, data, expires_at:, from_cache:)
    daily = data.fetch("daily")

    unless daily.is_a?(Hash)
      raise Error, "Invalid daily forecast data"
    end

    dates = daily.fetch("time")
    maximum_temperatures = daily.fetch("temperature_2m_max")
    minimum_temperatures = daily.fetch("temperature_2m_min")

    validate_daily_data!(
      dates,
      maximum_temperatures,
      minimum_temperatures
    )

    Forecast.new(
      address: address,
      dates: dates,
      maximum_temperatures: maximum_temperatures,
      minimum_temperatures: minimum_temperatures,
      expires_at: expires_at,
      from_cache: from_cache
    )
  end

  def validate_daily_data!(
    dates,
    maximum_temperatures,
    minimum_temperatures
  )
    arrays = [
      dates,
      maximum_temperatures,
      minimum_temperatures
    ]

    unless arrays.all?(Array)
      raise Error, "Invalid daily forecast data"
    end

    unless arrays.map(&:length).uniq.one?
      raise Error, "Daily forecast arrays have inconsistent lengths"
    end

    if dates.empty?
      raise Error, "Daily forecast data is empty"
    end
  end

  def log_failed_response(response)
    Rails.logger.error(
      "Open-Meteo request failed " \
      "status=#{response.code} " \
      "body=#{response.body.to_s.truncate(1_000)}"
    )
  end

  def fetch_forecast(location)
    response = request(
      latitude: location.fetch("lat"),
      longitude: location.fetch("lon")
    )

    unless response.is_a?(Net::HTTPSuccess)
      log_failed_response(response)

      raise Error,
            "Open-Meteo request failed with HTTP #{response.code}"
    end

    JSON.parse(response.body)
  rescue JSON::ParserError => e
    raise Error, "Invalid JSON response from Open-Meteo: #{e.message}"
  rescue KeyError, TypeError => e
    raise Error, "Unexpected response from Open-Meteo: #{e.message}"
  rescue *NETWORK_ERRORS => e
    raise Error, "Open-Meteo request failed: #{e.message}"
  end
end