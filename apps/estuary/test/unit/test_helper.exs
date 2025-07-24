ExUnit.start(exclude: [:skip])
Faker.start()
TelemetryEvent.Mock.start_link()
Application.ensure_all_started(:estuary)
