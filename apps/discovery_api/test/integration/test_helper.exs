alias DiscoveryApi.Test.Helper

Divo.Suite.start()
Helper.wait_for_brook_to_be_ready()
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
