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
- For Configuring Telemetry for the app:

```
TelemetryEvent.config_init_server(child, app_name)
```

child:

  - List of child being passed to Supervisor

app_name:
  - Name of the app


- For passing the event to telemetry metrics:

```
TelemetryEvent.add_event_metrics(event_measurements, event_name)
```

event_measurements:

For `events_handeled`:
  - app: Name of the app
  - author: Name of the author
  - dataset_id: Dataset Id
  - event_type: Type of the event

For `dead_letters_handeled`:
  - dataset_id: Dataset Id
  - reason: Reason of dead letter (It should be sent as String)

- The above fields are mandatory.
- If the value of any of the fields are nil or `""` the it will be replaced with `UNKNOWN`

event_name:

  - Name of the event (eg: [:events_handled] or [:dead_letters_handled] .... or any other name being used)



### PORT NO AND OTHER OPTIONS FOR PROD
- The port no and other options can be configured in each app separately as follows:

```
config :telemetry_event,
  metrics_port: 9002,
  init_server: true,
  metrics_options: [
    [
      metric_name: "events_handled.count",
      tags: [:app, :author, :dataset_id, :event_type]
    ],
    [
      metric_name: "dead_letters_handled.count",
      tags: [:dataset_id, :reason]
    ]
  ]
```

- The above port no is just an example, its not mandatory to use the same port for each app.
- Init Server is optional by default it is `true` and it is not required.
- The above metrics_options can is just an example, any no of metrics can be added to it depending upon the requirement of the app.


### PORT NO FOR TEST AND INTEGRATION
- Upon starting any application for test and integration, it will assign the metrics port dynamically which can be fetched using Application.get_env, for example:

```
Application.get_env(:telemetry_event, :metrics_port)
```

- It will return a four digit port no as output, for example:

```
2168
```

### INIT SERVER FOR TEST AND INTEGRATION
- For test and integration `init_server` is set to `false` so that telemetry is not initialized for test and integration, if it is required startup telemetry app then it can be set to true.
