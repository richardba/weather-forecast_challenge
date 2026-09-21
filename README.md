# Weather Forecast

Simple Rails application that retrieves a 3-day weather forecast for a searched location.

It uses:

- Nominatim for address geocoding
- Open-Meteo for weather data
- Rails cache for geocoding and forecast responses
- Stimulus for forecast expiration in the UI
- RSpec for tests

## Setup

Install dependencies:

```bash
bundle install
````
Set the required Nominatim user agent:

```bash
export NOMINATIM_USER_AGENT="weather-app/1.0 your-email@example.com"
```

On PowerShell:

```powershell
$env:NOMINATIM_USER_AGENT="weather-app/1.0 your-email@example.com"
```

Start the application:

```bash
bin/rails server
```

Then open:

```text
http://localhost:3000/forecast
```

## Tests

```bash
bundle exec rspec
```
