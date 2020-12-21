# TELEMETRY_EVENT

Generates metrics for the events

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

#### child:

  - List of child being passed to Supervisor

#### app_name:
  - Name of the app


- For passing the event to telemetry metrics:

```
TelemetryEvent.add_event_metrics(event_measurements, event_name)
```

#### event_measurements:

For `events_handeled`:
  - app: Name of the app
  - author: Name of the author
  - dataset_id: Dataset Id
  - event_type: Type of the event

For `dead_letters_handeled`:
  - dataset_id: Dataset Id
  - reason: Reason of dead letter (It should be sent as String)

- NOTE:
  - The above fields are mandatory.
  - If the value of any of the fields are nil or `""` the it will be replaced with `UNKNOWN`

#### event_name:
  - Name of the event (eg: [:events_handled] or [:dead_letters_handled] .... or any other name being used)



### PORT NO AND OTHER OPTIONS FOR PROD
  - The port no and other options can be configured in each app separately as follows:

```
config :telemetry_event,
  metrics_port: 9002,
  init_server: true,
  add_poller: true,
  add_metrics: [:dead_letters_handled_count, :phoenix_endpoint_stop_duration, :dataset_total_count],
  metrics_options: [
    [
      metric_name: "events_handled.count",
      tags: [:app, :author, :dataset_id, :event_type],
      metric_type: :counter
    ],
    [
      metric_name: "downloaded_csvs.count",
      tags: [:app, :DatasetId, :Table],
      metric_type: :counter
    ],
    [
      metric_name: "data_queries.count",
      tags: [:app, :DatasetId, :Table, :ContentType],
      metric_type: :counter
    ],
    [
      metric_name: "dataset_compaction_duration_total.duration",
      tags: [:app, :system_name],
      metric_type: :last_value
    ],
    [
      metric_name: "dataset_record_total.count",
      tags: [:system_name],
      metric_type: :last_value
    ],
    [
      metric_name: "phoenix.endpoint.stop.duration",
      tags: [:app, :end_point, :method],
      tag_values: fn %{conn: conn} ->
        %{app: app(conn), end_point: end_point(conn), method: Map.get(conn, :method)}
      end,
      metric_type: :distribution,
      unit: {:native, :millisecond},
      reporter_options: [buckets: [10, 50, 100, 250, 500, 1000, 2000]]
    ]
  ]
```
- NOTE:
  - By default `events_handeled` metric will be added in metrics_options with the above tags, hence there is no need to add it separately.


#### metrics_port:
  - The above port no is just an example, its not mandatory to use the same port for each app.

#### init_server:
  - Init Server is optional by default it is `true` and it is not required.

#### add_poller:
  - Add Poller is optional.
  - For adding `:telemetry_poller` in Init Server Configuration, it is required to set this to `true`.

#### add_metrics:
  - Add Metrics is optional and can be added if any of the following metrics are required:
    - `:dead_letters_handled_count`
    - `:phoenix_endpoint_stop_duration`
    - `:dataset_total_count`
  - The above metrics configuration can be added just by adding the keys shown above.
  - All the above metrics are optional and can be added depending upon the requirement.

#### metrics_options:
  - Metrics Options is optional and can be added if any new metrics is required.
  - The above metrics_options is just an example, any no of metrics can be added to it depending upon the requirement of the app.

#### metric_name:
  - This includes the name of the metrics followed by the measurement.
  - Anything before the last `.` is considered as the name of the metrics and anything after the last `.` is the measurement of the metrics.
  - For eg: `events_handled.count` - Here, `events_handled` is the name of the metrics and the `count` is the measurement.

#### tags:
  - This includes the list of the atoms to for required keys.
  - For eg: `[:app, :system_name]` - Here, two keys are used, `app` and `system_name`

#### tag_values:
  - This is optional function that receives the metadata and returns a map with the tags as keys and their respective values.
  - By defaults it returns the metadata itself.
  - For eg: In the above metrics `phoenix.endpoint.stop.duration`, `tag_values` is used to fetch `app`(Name of the app), `end_point`(Endpoint called) and `method`(Method used: GET, POST, PUT, DELETE) from tne `conn`.

#### metric_type:
  - This indicates the type of metric required.
  - It must be one of the the following options:
    - `:counter` Metric - It keeps track of the total number of specific events emitted.
    - `:sum` Metric - It keeps track of the sum of selected measurement's values carried by specific events.
    - `:last_value` Metric - It keeps track of the selected measurement found in the most recent event.
    - `:distribution` Metric - It builds a histogram of selected measurement's values. It is up to the reporter to decide how the boundaries of the distribution buckets are configured - via :reporter_options, configuration of the aggregating system, or other means.

#### unit:
  - This is optional, includes an atom describing the unit of selected measurement.
  - Currently, only time and byte unit conversions are supported.

#### reporter_options:
  - This includes a keyword list of reporter-specific options for the metric.

#### buckets:
  - It is up to the reporter to decide how the boundaries of the distribution buckets are configured - via :reporter_options, configuration of the aggregating system, or other means.

### PORT NUMBER FOR TEST AND INTEGRATION
  - Upon starting any application for test and integration, it will assign the metrics port dynamically which can be fetched using Application.get_env, for example:

```
Application.get_env(:telemetry_event, :metrics_port)
```

  - It will return a four digit port number as output, for example:

```
2168
```

### INIT SERVER FOR TEST AND INTEGRATION
  - For test and integration `init_server` is set to `false` so that telemetry is not initialized for test and integration, if it is required startup telemetry app then it can be set to true.
