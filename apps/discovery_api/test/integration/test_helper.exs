alias DiscoveryApi.Test.Helper

# Ensure Mix application is loaded
Application.ensure_all_started(:mix)

# Load support files after the application is ready
Code.require_file("support/elasticsearch_case.ex", __DIR__)
Code.require_file("support/data_case.ex", __DIR__)

# Load behaviour and implementation files
Code.require_file("../unit/support/raptor_service_behaviour.ex", __DIR__)
Code.require_file("../support/raptor_service_test_impl.ex", __DIR__)

Divo.Suite.start()
Helper.wait_for_brook_to_be_ready()
Helper.wait_for_elasticsearch_to_be_ready()
Faker.start()
ExUnit.start(timeout: 300_000)

defmodule URLResolver do
  def resolve_url(url) do
    "./test/integration/schemas/#{url}"
    |> String.split("#")
    |> List.last()
    |> File.read!()
    |> Jason.decode!()
    |> remove_urls()
  end

  def remove_urls(map) do
    Map.put(map, "id", "./test/integration/schemas/")
  end
end
