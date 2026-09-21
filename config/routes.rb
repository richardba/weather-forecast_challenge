Rails.application.routes.draw do
  get "/forecast", to: "forecast#show", as: :forecast
end