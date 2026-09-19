require "net/http"
require "uri"
require "json"
require "openssl"
require "digest"

class AddressService
  class Error < StandardError; end

  ENDPOINT = URI("https://nominatim.openstreetmap.org/search").freeze
  CACHE_EXPIRATION = 24.hours

  NETWORK_ERRORS = [
    Timeout::Error,
    SocketError,
    EOFError,
    Errno::ECONNREFUSED,
    Errno::ECONNRESET,
    Errno::ETIMEDOUT,
    OpenSSL::SSL::SSLError
  ].freeze

  def initialize(user_agent:, cache: Rails.cache)
    @user_agent = user_agent
    @cache = cache
  end

  def call(address)
    @cache.fetch(cache_key(address), expires_in: CACHE_EXPIRATION) do
      fetch_location(address)
    end
  end

  private

  def fetch_location(address)
    response = request(address)

    unless response.is_a?(Net::HTTPSuccess)
      log_failed_response(response)

      raise Error,
            "Nominatim request failed with HTTP #{response.code}"
    end

    parse_response(response.body)
  rescue JSON::ParserError => e
    raise Error, "Invalid JSON response from Nominatim: #{e.message}"
  rescue *NETWORK_ERRORS => e
    raise Error, "Nominatim request failed: #{e.message}"
  end

  def parse_response(body)
    data = JSON.parse(body)

    unless data.is_a?(Array)
      raise Error, "Unexpected response from Nominatim"
    end

    data
  end

  def request(address)
    uri = ENDPOINT.dup

    uri.query = URI.encode_www_form(
      q: address.query,
      format: "json",
      addressdetails: 1,
      limit: 1
    )

    request = Net::HTTP::Get.new(uri)
    request["User-Agent"] = @user_agent
    request["Accept"] = "application/json"

    Net::HTTP.start(
      uri.hostname,
      uri.port,
      use_ssl: true,
      open_timeout: 5,
      read_timeout: 10
    ) do |http|
      http.request(request)
    end
  end

  def cache_key(address)
    normalized_query = address.query.to_s.strip.downcase
    digest = Digest::SHA256.hexdigest(normalized_query)

    "address_service:nominatim:#{digest}"
  end

  def log_failed_response(response)
    Rails.logger.error(
      "Nominatim request failed " \
      "status=#{response.code} " \
      "body=#{response.body.to_s.truncate(1_000)}"
    )
  end
end