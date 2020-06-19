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
TelemetryEvent.TelemetryHelper.add_event_count(options[])
```

Options:

  - app: Name of the app
  - author: Name of the author
  - dataset_id: Dataset Id
  - event_type: Type of the event


### PORT NO FOR PROD
- The port no can be configured in each app separately as follows:

```
config :telemetry_event,
  metrics_port: 9002
```

The above port no is just an example, its not mandatory to use the same port.


### PORT NO FOR TEST AND INTEGRATION
- Upon starting any application it will show the port no as the message for example:

```
Telemetry Prometheus Metrics is hosted on Port No: 9633
```
