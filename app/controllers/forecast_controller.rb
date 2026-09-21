class ForecastController < ApplicationController
  def show
    @address = Address.new(address_params)

    address_service = AddressService.new(
      user_agent: ENV.fetch("NOMINATIM_USER_AGENT")
    )

    forecast_service = ForecastService.new(
      address_service: address_service
    )

    @forecasts = recent_forecasts(forecast_service)

    if params.key?(:address)
      forecast = forecast_service.call(@address)

      remember_search(forecast)

      @forecasts.reject! do |existing_forecast|
        existing_forecast.address.query.casecmp?(
          forecast.address.query
        )
      end

      @forecasts << forecast
    end

    respond_to do |format|
      format.html
      format.json { render json: @forecasts }
    end
  rescue ForecastService::InvalidAddress => e
    @error = e.message
    respond_with_error(:bad_request)
  rescue ForecastService::AddressNotFound => e
    @error = e.message
    respond_with_error(:not_found)
  rescue AddressService::Error, ForecastService::Error
    @error = "Weather service temporarily unavailable"
    respond_with_error(:bad_gateway)
  end

  private

  def address_params
    params
      .permit(address: [:query])
      .fetch(:address, {})
  end

  def remember_search(forecast)
    session[:forecast_searches] ||= []

    query = forecast.address.query

    session[:forecast_searches].reject! do |item|
      item["query"].casecmp?(query)
    end

    session[:forecast_searches] << {
      "query" => query,
      "expires_at" => forecast.expires_at.iso8601
    }
  end

  def recent_forecasts(forecast_service)
    searches = session[:forecast_searches] || []

    active_searches = searches.select do |item|
      expires_at = Time.zone.parse(item["expires_at"].to_s)

      expires_at.present? && expires_at.future?
    end

    session[:forecast_searches] = active_searches

    active_searches.filter_map do |item|
      forecast = forecast_service.call(
        Address.new(query: item["query"])
      )

      # Keep the display expiration tied to the original search.
      forecast.expires_at = item["expires_at"]

      forecast
    rescue ForecastService::AddressNotFound
      nil
    end
  end

  def respond_with_error(status)
    respond_to do |format|
      format.html { render :show, status: status }

      format.json do
        render json: { error: @error }, status: status
      end
    end
  end
end