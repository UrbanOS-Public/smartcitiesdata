# TELEMETRY_EVENT

Generates standard messages for Dead Letter Queue

## Installation

The package can be installed by adding `telemetry_event` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:telemetry_event, in_umbrella: :true}
  ]
end
```

## Usage

```
TelemetryEvent.TelemetryHelper.add_event_count(options \\ [])
```

Options:

  - app: Name of the app
  - author: Name of the author
  - dataset_id: Dataset Id
  - event_type: Type of the event
