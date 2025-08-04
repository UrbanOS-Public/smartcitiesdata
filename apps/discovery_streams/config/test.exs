import Config

config :discovery_api, ecto_repos: [DiscoveryApi.Repo]

# Mock configurations for testing
config :discovery_streams,
  raptor_service: RaptorServiceMock,
  brook_view_state: BrookViewStateMock,
  elsa: ElsaMock,
  topic_helper: TopicHelperMock,
  telemetry_event: DiscoveryStreamsTelemetryEventMock,
  dead_letter: DeadLetterMock,
  stream_supervisor: StreamSupervisorMock

# Mock TelemetryEvent at the application level to avoid conflicts
config :telemetry_event,
  implementation: DiscoveryStreamsTelemetryEventMock

# Brook configuration for testing
config :discovery_streams, :brook,
  instance: :discovery_streams,
  driver: [
    module: Brook.Driver.Test,
    init_arg: []
  ],
  handlers: [DiscoveryStreams.Event.EventHandler],
  storage: [
    module: Brook.Storage.Ets,
    init_arg: [
      namespace: "discovery_streams:view"
    ]
  ]