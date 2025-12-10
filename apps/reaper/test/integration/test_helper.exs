ExUnit.start(exclude: [:skip, :performance])

Application.load(:reaper)

Application.spec(:reaper, :applications)
|> Enum.each(&Application.ensure_all_started/1)

# Ensure tzdata is started for DateTime operations in tests
Application.ensure_all_started(:tzdata)

# Ensure bypass is started for HTTP mocking in tests
Application.ensure_all_started(:bypass)

{:ok, _} = TelemetryEvent.Mock.start_link()

# Set required environment variables for Reaper application to start
# Use minioadmin credentials to match the MinIO container configuration
System.put_env("AWS_ACCESS_KEY_ID", "minioadmin")
System.put_env("AWS_ACCESS_KEY_SECRET", "minioadmin")

# Note: The Reaper application will be started by Divo after Docker services are ready
# Do NOT start it here as Redis and Kafka may not be available yet
