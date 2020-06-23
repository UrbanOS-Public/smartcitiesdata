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

  - app: Name of the app (Mandatory Field)
  - author: Name of the author (Mandatory Field)
  - dataset_id: Dataset Id (Optional Field, can be `nil`)
  - event_type: Type of the event (Mandatory Field)


### PORT NO FOR PROD
- The port no can be configured in each app separately as follows:

```
config :telemetry_event,
  metrics_port: 9002
```

The above port no is just an example, its not mandatory to use the same port for each app.


### PORT NO FOR TEST AND INTEGRATION
- Upon starting any application for test and integration, it will assign the metrics port dynamically which can be fetched using Application.get_env, for example:

```
Application.get_env(:telemetry_event, :metrics_port)
```

- It will return a four digit port no as output, for example:

```
2168
```
