defmodule Andi.IngestionControllerTest do
  use ExUnit.Case

  use Andi.DataCase
  use Tesla
  use Properties, otp_app: :andi

  @moduletag shared_data_connection: true

  import SmartCity.TestHelper, only: [eventually: 1]

  import SmartCity.Event,
    only: [
      dataset_disable: 0,
      dataset_delete: 0,
      dataset_update: 0,
      ingestion_delete: 0,
      ingestion_update: 0
    ]

  alias SmartCity.TestDataGenerator, as: TDG
  alias Andi.Services.DatasetStore
  alias Andi.InputSchemas.Datasets
  alias Andi.Services.IngestionStore
  alias Andi.InputSchemas.Ingestions
  alias Andi.InputSchemas.Datasets

  plug(Tesla.Middleware.BaseUrl, "http://localhost:4000")
  getter(:kafka_broker, generic: true)

  describe "ingestion delete" do
    test "sends ingestion:delete event" do
      dataset = setup_dataset()
      ingestion = TDG.create_ingestion(%{id: nil, sourceType: "remote", targetDataset: dataset["id"]})
      {:ok, response} = create_ingestion(ingestion)
      body = response.body |> Jason.decode!()

      eventually(fn ->
        {:ok, value} = IngestionStore.get(body["id"])
        assert value != nil
      end)

      post("/api/v1/ingestion/delete", %{id: body["id"]} |> Jason.encode!(), headers: [{"content-type", "application/json"}])

      eventually(fn ->
        values =
          Elsa.Fetch.fetch(kafka_broker(), "event-stream")
          |> elem(2)
          |> Enum.filter(fn message ->
            message.key == ingestion_delete() && String.contains?(message.value, body["id"])
          end)

        assert 1 = length(values)
      end)

      eventually(fn ->
        {:ok, value} = IngestionStore.get(body["id"])
        assert value == nil
      end)
    end

    test "returns 404 when ingestion does not exist in database" do
      {:ok, %{status: 404, body: body}} =
        post("/api/v1/ingestion/delete", %{id: "invalid-ingestion-id"} |> Jason.encode!(), headers: [{"content-type", "application/json"}])

      assert Jason.decode!(body) == "Ingestion not found"
    end
  end

  describe "ingestion publish" do
    test "sends ingestion:update event" do
      dataset = setup_dataset()
      ingestion = TDG.create_ingestion(%{id: nil, sourceType: "remote", targetDataset: dataset["id"]})
      {:ok, response} = create_ingestion(ingestion)
      body = response.body |> Jason.decode!()

      eventually(fn ->
        {:ok, value} = IngestionStore.get(body["id"])
        assert value != nil
      end)

      post("/api/v1/ingestion/publish", %{id: body["id"]} |> Jason.encode!(), headers: [{"content-type", "application/json"}])

      eventually(fn ->
        values =
          Elsa.Fetch.fetch(kafka_broker(), "event-stream")
          |> elem(2)
          |> Enum.filter(fn message ->
            message.key == ingestion_update() && String.contains?(message.value, body["id"])
          end)

        assert 2 == length(values)
      end)

      eventually(fn ->
        assert Ingestions.get(body["id"]).submissionStatus == :published
      end)

      # TODO: Refactor the create/publish endpoints to be merged into a single "update" endpoint
      # TODO: The create/publish split makes sense for the UI Draft/Publish, but the API cannot create a draft
      # This sleep is a band-aid for a Repo/Event-Stream race condition
      Process.sleep(3_000)
    end

    test "returns 404 when ingestion does not exist in database" do
      {:ok, %{status: 404, body: body}} =
        post("/api/v1/ingestion/publish", %{id: Faker.UUID.v4()} |> Jason.encode!(), headers: [{"content-type", "application/json"}])

      assert Jason.decode!(body) == "Ingestion not found"
    end
  end

  describe "ingestion put" do
    test "writes data to event stream" do
      dataset = setup_dataset()
      uuid = Faker.UUID.v4()

      request = %{
        "name" => "Name",
        "extractSteps" => [
          %{"type" => "http", "context" => %{"url" => "http://example.com", "action" => "GET"}}
        ],
        "sourceFormat" => "application/gtfs+protobuf",
        "cadence" => "*/9000 * * * * *",
        "schema" => [%{name: "billy", type: "writer"}],
        "targetDataset" => dataset["id"],
        "topLevelSelector" => "$.someValue",
        "transformations" => []
      }

      assert {:ok, %{status: 201, body: body}} = create_ingestion(request)
      response = Jason.decode!(body)

      eventually(fn ->
        assert IngestionStore.get(response["id"]) != {:ok, nil}
      end)

      struct = SmartCity.Ingestion.new(response)

      eventually(fn ->
        values =
          Elsa.Fetch.fetch(kafka_broker(), "event-stream")
          |> elem(2)
          |> Enum.map(fn response ->
            {:ok, brook_message} = Brook.Deserializer.deserialize(response.value)
            brook_message
          end)
          |> Enum.filter(fn response ->
            response.type == ingestion_update()
          end)
          |> Enum.map(fn response ->
            response.data
          end)

        assert struct in values
      end)
    end

    test "put returns 400 and errors when fields are invalid" do
      dataset = setup_dataset()
      uuid = Faker.UUID.v4()

      new_ingestion =
        TDG.create_ingestion(%{
          id: nil,
          extractSteps: [
            %{"type" => "http", "context" => %{"url" => "example.com", "action" => "GET"}}
          ],
          sourceFormat: "application/gtfs+protobuf",
          cadence: "*/9000 * * * * *",
          schema: [%{name: "billy", type: "writer"}],
          targetDataset: dataset["id"],
          topLevelSelector: "$.someValue",
          transformations: []
        })
        |> struct_to_map_with_string_keys()
        |> delete_in([
          ["cadence"],
          ["sourceFormat"]
        ])

      {:ok, %{status: 400, body: body}} = create_ingestion(new_ingestion)

      actual_errors =
        Jason.decode!(body)
        |> Map.get("errors")

      expected_error_keys = [
        ["cadence"],
        ["sourceFormat"]
      ]

      for key <- expected_error_keys do
        assert get_in(actual_errors, key) != nil
      end
    end

    test "put trims fields on ingestion" do
      dataset = setup_dataset()
      uuid = Faker.UUID.v4()

      new_ingestion =
        TDG.create_ingestion(%{
          id: nil,
          sourceFormat: "application/gtfs+protobuf",
          cadence: "     */9000 * * * * *",
          schema: [%{name: "billy", type: "writer   "}],
          targetDataset: "#{dataset["id"]}   ",
          topLevelSelector: "   $.someValue",
          transformations: []
        })

      {:ok, %{status: 201, body: body}} = create_ingestion(new_ingestion)
      response = Jason.decode!(body)

      eventually(fn ->
        assert IngestionStore.get(response["id"]) != {:ok, nil}
      end)

      assert response["cadence"] == "*/9000 * * * * *"
      assert response["topLevelSelector"] == "$.someValue"
      assert response["targetDataset"] == dataset["id"]
      assert response["sourceFormat"] == "application/gtfs+protobuf"
      assert response["topLevelSelector"] == "$.someValue"
      assert List.first(response["schema"])["type"] == "writer"
    end

    test "PUT /api/ingestion passed without UUID generates UUID for dataset" do
      dataset = setup_dataset()
      uuid = Faker.UUID.v4()

      new_ingestion =
        TDG.create_ingestion(%{
          id: nil,
          name: "Name",
          targetDataset: dataset["id"],
          transformations: [],
          extractSteps: [
            %{
              type: "http",
              context: %{
                action: "GET",
                url: "http://example.com"
              }
            }
          ]
        })

      {:ok, %{status: 201, body: body}} = create_ingestion(new_ingestion)
      response = Jason.decode!(body)

      eventually(fn ->
        assert IngestionStore.get(response["id"]) != {:ok, nil}
      end)

      uuid = response["id"]

      assert uuid != nil
    end

    test "returns 400 when cron string is longer than 6 characters" do
      dataset = setup_dataset()

      new_ingestion =
        TDG.create_ingestion(%{
          id: nil,
          cadence: "*/9000 * * * * * * *",
          targetDataset: dataset["id"],
          topLevelSelector: "$.someValue"
        })

      {:ok, %{status: 400, body: body}} = create_ingestion(new_ingestion)
    end
  end

  describe "dataset get" do
    test "andi doesn't return server in response headers" do
      {:ok, %Tesla.Env{headers: headers}} = get("/api/v1/ingestions", headers: [{"content-type", "application/json"}])

      refute headers |> Map.new() |> Map.has_key?("server")
    end
  end

  defp create_dataset(dataset) do
    struct = Jason.encode!(dataset)
    put("/api/v1/dataset", struct, headers: [{"content-type", "application/json"}])
  end

  defp create_ingestion(ingestion) do
    struct = Jason.encode!(ingestion)
    put("/api/v1/ingestion", struct, headers: [{"content-type", "application/json"}])
  end

  defp struct_to_map_with_string_keys(dataset) do
    dataset
    |> Jason.encode!()
    |> Jason.decode!()
  end

  defp delete_in(data, paths) do
    Enum.reduce(paths, data, fn path, working ->
      working |> pop_in(path) |> elem(1)
    end)
  end

  defp setup_dataset() do
    dataset = TDG.create_dataset(%{technical: %{sourceType: "remote"}})
    {:ok, response} = create_dataset(%SmartCity.Dataset{dataset | id: nil})

    body = response.body |> Jason.decode!()

    eventually(fn ->
      {:ok, value} = DatasetStore.get(body["id"])
      assert value != nil
    end)

    body
  end
end
