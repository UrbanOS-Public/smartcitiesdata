ExUnit.start(exclude: [:skip])

# Configure Mox for mocks
Mox.defmock(StreamSupervisorMock, for: DiscoveryStreams.StreamSupervisorBehaviour)
Mox.defmock(BrookViewStateMock, for: BrookMock)
Mox.defmock(ElsaMock, for: ElsaMock)
Mox.defmock(TopicHelperMock, for: DiscoveryStreams.TopicHelperBehaviour)
Mox.defmock(RaptorServiceMock, for: RaptorServiceBehaviour)
Mox.defmock(TelemetryEventMock, for: TelemetryEventBehaviour)
Mox.defmock(DeadLetterMock, for: DeadLetterBehaviour)
