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
      ingestion = TDG.create_ingestion(%{sourceType: "remote", targetDataset: dataset.id})
      {:ok, _} = create_ingestion(ingestion)

      eventually(fn ->
        {:ok, value} = IngestionStore.get(ingestion.id)
        assert value != nil
      end)

      post("/api/v1/ingestion/delete", %{id: ingestion.id} |> Jason.encode!(), headers: [{"content-type", "application/json"}])

      eventually(fn ->
        values =
          Elsa.Fetch.fetch(kafka_broker(), "event-stream")
          |> elem(2)
          |> Enum.filter(fn message ->
            message.key == ingestion_delete() && String.contains?(message.value, ingestion.id)
          end)

        assert 1 = length(values)
      end)

      eventually(fn ->
        {:ok, value} = IngestionStore.get(ingestion.id)
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
      ingestion = TDG.create_ingestion(%{sourceType: "remote", targetDataset: dataset.id})
      {:ok, _} = create_ingestion(ingestion)

      eventually(fn ->
        {:ok, value} = IngestionStore.get(ingestion.id)
        assert value != nil
      end)

      post("/api/v1/ingestion/publish", %{id: ingestion.id} |> Jason.encode!(), headers: [{"content-type", "application/json"}])

      eventually(fn ->
        values =
          Elsa.Fetch.fetch(kafka_broker(), "event-stream")
          |> elem(2)
          |> Enum.filter(fn message ->
            message.key == ingestion_update() && String.contains?(message.value, ingestion.id)
          end)

        assert 2 == length(values)
      end)

      eventually(fn ->
        assert Ingestions.get(ingestion.id).submissionStatus == :published
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
    setup do
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
        "targetDataset" => dataset.id,
        "topLevelSelector" => "$.someValue",
        "transformations" => []
      }

      message =
        request
        |> SmartCity.Helpers.to_atom_keys()
        |> TDG.create_ingestion()
        |> struct_to_map_with_string_keys()
        |> Map.pop("id")

      assert {:ok, %{status: 201, body: body}} = create_ingestion(request)
      response = Jason.decode!(body)

      eventually(fn ->
        assert IngestionStore.get(request["id"]) != {:ok, nil}
      end)

      {:ok, response: response, message: message}
    end

    test "writes data to event stream", %{message: message} do
      struct = SmartCity.Ingestion.new(message)

      eventually(fn ->
        values =
          Elsa.Fetch.fetch(kafka_broker(), "event-stream")
          |> elem(2)
          |> Enum.map(fn message ->
            {:ok, brook_message} = Brook.Deserializer.deserialize(message.value)
            brook_message
          end)
          |> Enum.filter(fn message ->
            message.type == ingestion_update()
          end)
          |> Enum.map(fn message ->
            message.data
          end)

        assert struct in values
      end)
    end

    test "put returns 400 and errors when fields are invalid" do
      dataset = setup_dataset()
      uuid = Faker.UUID.v4()

      new_ingestion =
        TDG.create_ingestion(%{
          id: uuid,
          extractSteps: [
            %{"type" => "http", "context" => %{"url" => "example.com", "action" => "GET"}}
          ],
          sourceFormat: "application/gtfs+protobuf",
          cadence: "*/9000 * * * * *",
          schema: [%{name: "billy", type: "writer"}],
          targetDataset: dataset.id,
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
          sourceFormat: "application/gtfs+protobuf",
          cadence: "     */9000 * * * * *",
          schema: [%{name: "billy", type: "writer   "}],
          targetDataset: "#{dataset.id}   ",
          topLevelSelector: "   $.someValue",
          transformations: []
        })

      {:ok, %{status: 201, body: body}} = create_ingestion(new_ingestion)
      response = Jason.decode!(body)

      eventually(fn ->
        assert IngestionStore.get(new_ingestion.id) != {:ok, nil}
      end)

      assert response["cadence"] == "*/9000 * * * * *"
      assert response["topLevelSelector"] == "$.someValue"
      assert response["targetDataset"] == dataset.id
      assert response["sourceFormat"] == "application/gtfs+protobuf"
      assert response["topLevelSelector"] == "$.someValue"
      assert List.first(response["schema"])["type"] == "writer"
    end

    test "PUT /api/ingestion passed without UUID generates UUID for dataset" do
      dataset = setup_dataset()
      uuid = Faker.UUID.v4()

      new_ingestion =
        TDG.create_ingestion(%{
          name: "Name",
          targetDataset: dataset.id,
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

      {_, new_ingestion} = pop_in(new_ingestion, ["id"])

      {:ok, %{status: 201, body: body}} = create_ingestion(new_ingestion)

      eventually(fn ->
        assert IngestionStore.get(new_ingestion.id) != {:ok, nil}
      end)

      uuid =
        Jason.decode!(body)
        |> get_in(["id"])

      assert uuid != nil
    end

    test "returns 400 when cron string is longer than 6 characters" do
      dataset = setup_dataset()

      new_ingestion =
        TDG.create_ingestion(%{
          cadence: "*/9000 * * * * * * *",
          targetDataset: dataset.id,
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
    {:ok, _} = create_dataset(dataset)

    eventually(fn ->
      {:ok, value} = DatasetStore.get(dataset.id)
      assert value != nil
    end)

    dataset
  end
end
