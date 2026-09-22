class Forecast
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :address
  attribute :dates
  attribute :maximum_temperatures
  attribute :minimum_temperatures
  attribute :expires_at, :datetime
  attribute :from_cache

  def days
    dates.zip(
      maximum_temperatures,
      minimum_temperatures
    ).map do |date, maximum, minimum|
      {
        date: date,
        maximum_temperature: maximum,
        minimum_temperature: minimum
      }
    end
  end

  def as_json(*)
    {
      address: address.query,
      days: days,
      expires_at: expires_at,
      from_cache: from_cache
    }
  end
end
