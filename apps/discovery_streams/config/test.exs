import Config
System.put_env("REQUIRE_API_KEY", "false")

host = "127.0.0.1"
endpoints = [{String.to_atom(host), 9092}]

config :discovery_streams, DiscoveryStreamsWeb.Endpoint,
  http: [port: 4001],
  server: false

config :discovery_streams,
  raptor_url: "raptor.url"

config :discovery_streams, endpoints: [localhost: 9092]

config :discovery_streams, :brook,
  instance: :discovery_streams,
  handlers: [DiscoveryStreams.Event.EventHandler],
  storage: [
    module: Brook.Storage.Ets,
    init_arg: []
  ],
  driver: [
    module: Brook.Driver.Default,
    init_arg: []
  ]

# Test module replacements
config :discovery_streams,
  stream_supervisor: StreamSupervisorMock,
  topic_helper: TopicHelperMock,
  raptor_service: RaptorServiceMock,
  telemetry_event: TelemetryEventMock,
  elsa: ElsaMock,
  brook: BrookViewStateMock,
  dead_letter: DeadLetterMock,
  start_brook: false,
  start_init: false
