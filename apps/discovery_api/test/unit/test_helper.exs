ExUnit.start(exclude: [:skip], capture_log: true)
Faker.start()

# Set up test authentication to bypass Guardian database requirements
DiscoveryApiWeb.Test.AuthTestHelper.setup_test_auth()

# Set up Mox for unit tests
DiscoveryApi.Test.MoxSetup.setup_mox()

# Start the TelemetryEvent.Mock process for compatibility
{:ok, _pid} = TelemetryEvent.Mock.start_link()

# Remove this - will handle DeadLetter stubs in individual tests

# Clean up test auth on exit
ExUnit.after_suite(fn _results ->
  DiscoveryApiWeb.Test.AuthTestHelper.cleanup_test_auth()
end)
