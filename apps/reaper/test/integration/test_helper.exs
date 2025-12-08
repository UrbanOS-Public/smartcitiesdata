ExUnit.start(exclude: [:skip, :performance])

Application.load(:reaper)

Application.spec(:reaper, :applications)
|> Enum.each(&Application.ensure_all_started/1)

# Ensure tzdata is started for DateTime operations in tests
Application.ensure_all_started(:tzdata)

# Ensure bypass is started for HTTP mocking in tests
Application.ensure_all_started(:bypass)

{:ok, _} = TelemetryEvent.Mock.start_link()
