ExUnit.start(exclude: [:skip])

# Load behavior modules
Code.require_file("../support/elsa_behaviour.ex", __DIR__)
Code.require_file("../support/dead_letter_behaviour.ex", __DIR__)
Code.require_file("../support/telemetry_event_behaviour.ex", __DIR__)

import Mox

# Configure Mox for mocks
defmock(ElsaMock, for: ElsaBehaviour)
defmock(DeadLetterMock, for: DeadLetterBehaviour)
defmock(ValkyrierTelemetryEventMock, for: TelemetryEventBehaviour)

# Start the TelemetryEvent.Mock process for compatibility
{:ok, _pid} = TelemetryEvent.Mock.start_link()
