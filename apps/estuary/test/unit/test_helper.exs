Application.ensure_all_started(:mox)
Application.ensure_all_started(:dead_letter)
ExUnit.start(exclude: [:skip])
Faker.start()
