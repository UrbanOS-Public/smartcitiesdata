ExUnit.start(exclude: [:skip])

Mox.defmock(ValkyrierTelemetryEventMock, for: TelemetryEvent.Behaviour)
{:ok, _} = TelemetryEvent.Mock.start_link()
