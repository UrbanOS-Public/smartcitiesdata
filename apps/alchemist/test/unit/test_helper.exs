ExUnit.start(exclude: [:skip])

# Start the TelemetryEvent.Mock process
{:ok, _pid} = TelemetryEvent.Mock.start_link()
