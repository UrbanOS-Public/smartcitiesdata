defmodule DiscoveryApi.Data.ProjectOpenDataTest do
  use ExUnit.Case
  use Divo.Integration

  @source_topic "dataset-registry"
  @name_space "discovery-api:project-open-data:"

  test "Properly formatted metadata is returned after consuming registry messages" do
    dataset = %SCOS.RegistryMessage{
      id: "erin",
      business: %{
        dataTitle: "my title",
        description: "description",
        modifiedDate: "2017-11-28T16:53:15.000Z",
        orgTitle: "Organization 1",
        contactName: "Bob Jones",
        contactEmail: "bjones@example.com",
        license: "http://openlicense.org",
        keywords: ["key", "words"]
      },
      technical: %{dataName: "", orgName: "", systemName: "", stream: "", sourceUrl: "", sourceFormat: ""}
    }

    dataset2 = %SCOS.RegistryMessage{
      id: "Ben",
      business: %{
        dataTitle: "my other title",
        description: "your description",
        modifiedDate: "2017-11-28T16:53:15.000Z",
        orgTitle: "Organization 2",
        contactName: "Bob Bob",
        contactEmail: "bb@example.com",
        license: "http://closedlicense.org",
        keywords: ["lock", "sentences"]
      },
      technical: %{dataName: "", orgName: "", systemName: "", stream: "", sourceUrl: "", sourceFormat: ""}
    }

    # Watching the leader log is causing intermittent failures. Adding a sleep until we upgrade divo to health check
    Process.sleep(2000)
    Mockaffe.send_to_kafka(dataset, @source_topic)
    Mockaffe.send_to_kafka(dataset2, @source_topic)

    Patiently.wait_for!(
      fn -> redix_populated?() end,
      dwell: 1000,
      max_tries: 20
    )

    actual =
      "http://localhost:4000/api/v1/data_json"
      |> HTTPoison.get!()
      |> Map.from_struct()
      |> Map.get(:body)
      |> Jason.decode!()

    schema =
      "./test/integration/schemas/catalog.json"
      |> File.read!()
      |> Jason.decode!()
      |> URLResolver.remove_urls()

    assert 2 ==
             actual
             |> Map.get("dataset")
             |> Enum.count()

    case ExJsonSchema.Validator.validate(schema, actual) do
      :ok ->
        assert true

      {:error, errors} ->
        IO.puts("Failed:" <> inspect(errors))
        flunk(errors)
    end
  end

  defp redix_populated?() do
    case Redix.command!(:redix, ["KEYS", @name_space <> "*"]) do
      [] ->
        false

      keys ->
        Enum.count(keys) == 2
    end
  end
end
