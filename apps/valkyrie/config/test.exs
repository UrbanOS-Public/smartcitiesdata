import Config

config :logger,
  level: :info

config :valkyrie,
  elsa_brokers: [localhost: 9092],
  retry_count: 5,
  retry_initial_delay: 10,
  input_topic_prefix: "raw",
  output_topic_prefix: "unit",
  broadway_producer_module: Fake.Producer

config :valkyrie, :brook,
  handlers: [Valkyrie.Event.EventHandler],
  storage: [
    module: Brook.Storage.Ets,
    init_arg: []
  ],
  hosted_file_bucket: "hosted-dataset-files"

config :valkyrie, :mox, mox_test: self()

# Mock configurations for testing
config :valkyrie,
  elsa: ElsaMock,
  telemetry_event: ValkyrierTelemetryEventMock

# Mock TelemetryEvent at the application level to avoid conflicts
config :telemetry_event,
  implementation: ValkyrierTelemetryEventMock
