ExUnit.start(exclude: [:skip])

import Mox

# Configure Mox for mocks
defmock(StreamSupervisorMock, for: DiscoveryStreams.StreamSupervisorBehaviour)
defmock(BrookViewStateMock, for: BrookMock)
defmock(ElsaMock, for: ElsaMock)
defmock(TopicHelperMock, for: DiscoveryStreams.TopicHelperBehaviour)
defmock(RaptorServiceMock, for: RaptorServiceBehaviour)
defmock(DiscoveryStreamsTelemetryEventMock, for: DiscoveryStreams.TelemetryEventBehaviour)
defmock(DeadLetterMock, for: DeadLetterBehaviour)
