Application.ensure_all_started(:mox)

ExUnit.start(exclude: [:skip])
Faker.start()
