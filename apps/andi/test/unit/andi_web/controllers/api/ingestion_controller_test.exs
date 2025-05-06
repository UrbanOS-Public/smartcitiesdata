defmodule AndiWeb.API.IngestionControllerTest do
  use AndiWeb.Test.AuthConnCase.UnitCase

  alias SmartCity.TestDataGenerator, as: TDG
  alias Andi.Services.IngestionStore
  alias Andi.Services.DatasetStore

  import Mock
  import SmartCity.Event, only: [ingestion_delete: 0, ingestion_update: 0]

  @instance_name Andi.instance_name()
  @route "/api/v1/ingestion"
  @get_ingestions_route "/api/v1/ingestions"

  setup_with_mocks([
    {Andi.Schemas.AuditEvents, [], [log_audit_event: fn(_, _, _) -> %{} end]},
    {Brook.Event, [:passthrough], [send: fn(@instance_name, _, :andi, _) -> :ok end]},
    {DatasetStore, [], [get: fn("dataset_id") -> {:ok, %{id: "dataset_id"}} end]}
  ]) do
    uuid = Faker.UUID.v4()

    request = %{
      "id" => uuid,
      "sourceFormat" => "gtfs",
      "cadence" => "once",
      "schema" => [%{name: "billy", type: "writer"}],
      "datasetId" => "dataset_id"
    }

    message =
      request
      |> SmartCity.Helpers.to_atom_keys()
      |> TDG.create_dataset()
      |> struct_to_map_with_string_keys()

    {:ok, request: request, message: message, example_ingestions: get_example_ingestions()}
  end

  describe "GET /ingestions" do
    @tag capture_log: true
    test "returns a 200", %{conn: conn, example_ingestions: example_ingestions} do
      with_mock(IngestionStore, [:passthrough], [get_all: fn() -> {:ok, example_ingestions} end]) do
        response =

        actual_ingestions =
          conn
          |> get(@get_ingestions_route)
          |> json_response(200)

        assert MapSet.new(example_ingestions) == MapSet.new(actual_ingestions)
      end
    end

    test "returns a 404", %{conn: conn} do
      with_mock(IngestionStore, [:passthrough], [get_all: fn() -> {:error, "this was an error"} end]) do
        response = get(conn, @get_ingestions_route)

        parsed_response =
          response
          |> json_response(404)

        assert parsed_response == "Unable to process your request"
      end
    end
  end

  describe "GET /ingestion:id" do
    @tag capture_log: true
    test "returns a 200", %{conn: conn} do
      %{id: id} = ingestion = TDG.create_ingestion(%{})

      with_mock(IngestionStore, [], [get: fn(^id) -> {:ok, ingestion} end]) do
        conn = get(conn, "/api/v1/ingestion/#{id}")

        response = conn |> json_response(200)
        assert Map.get(response, "id") == id
      end
    end

    test "returns a 404", %{conn: conn} do
      %{id: id} = TDG.create_ingestion(%{})

      with_mock(IngestionStore, [], [get: fn(^id) -> {:ok, nil} end]) do
        conn = get(conn, "/api/v1/ingestion/#{id}")

        response = conn |> json_response(404)

        assert response == "Ingestion not found"
      end
    end

    test "returns a 404 when an error is thrown by the IngestionStore", %{conn: conn} do
      with_mock(IngestionStore, [:passthrough], [get_all: fn() -> {:error, "this was an error"} end]) do
        response = get(conn, @get_ingestions_route)

        parsed_response =
          response
          |> json_response(404)

        assert parsed_response == "Unable to process your request"
      end
    end
  end

  describe "POST /ingestion/delete" do
    setup %{} do
      ingestion = TDG.create_ingestion(%{})
      [ingestion: ingestion]
    end

    test "should send ingestion:delete event", %{conn: conn, ingestion: ingestion} do
      with_mocks([
        {IngestionStore, [], [get: fn(_) -> {:ok, ingestion} end]},
        {Brook.Event, [], [send: fn(@instance_name, _, _, _) -> :ok end]}
      ]) do
        post(conn, "#{@route}/delete", %{id: ingestion.id})
        |> json_response(200)

        assert_called(Brook.Event.send(@instance_name, ingestion_delete(), :andi, ingestion))

        assert_called_exactly(Andi.Schemas.AuditEvents.log_audit_event(:api, ingestion_delete(), ingestion), 1)
      end
    end

    @tag capture_log: true
    test "does not send ingestion:delete event if ingestion does not exist", %{
      conn: conn,
      ingestion: ingestion
    } do
      with_mocks([
        {IngestionStore, [], [get: fn(_) -> {:ok, nil} end]},
        {Brook.Event, [], [send: fn(@instance_name, _, _, _) -> :ok end]}
      ]) do
        post(conn, "#{@route}/delete", %{id: ingestion.id})
        |> json_response(404)

        assert_not_called(Brook.Event.send(@instance_name, ingestion_delete(), :andi, ingestion))
      end
    end

    @tag capture_log: true
    test "handles error", %{conn: conn, ingestion: ingestion} do
      with_mocks([
        {IngestionStore, [], [get: fn(_) -> {:ok, ingestion} end]},
        {Brook.Event, [], [send: fn(@instance_name, _, _, _) -> {:error, "Mistakes were made"} end]}
      ]) do
        post(conn, "#{@route}/delete", %{id: ingestion.id})
        |> json_response(500)
      end
    end
  end

  describe "PUT /ingestion" do
    test "PUT /api/ with data returns a 201", %{conn: conn} do
      smrt_ingestion = TDG.create_ingestion(%{})
      {_, ingestion_without_id} = smrt_ingestion |> struct_to_map_with_string_keys() |> Map.pop("id")

      with_mocks([
        {Andi.InputSchemas.Datasets, [], [get: fn(_) -> %{technical: %{sourceType: "ingest"}} end]},
        {Brook.Event, [], [send: fn(@instance_name, _, _, _) -> :ok end]},
        {DatasetStore, [], [get: fn(_) -> {:ok, %{}} end]}
      ]) do
        conn = put(conn, @route, ingestion_without_id)

        {_, decoded_body} = Jason.decode(response(conn, 201))

        expected_ingestion = TDG.create_ingestion(Map.put(ingestion_without_id, "id", decoded_body["id"]))

        assert_called(Brook.Event.send(@instance_name, ingestion_update(), :andi, expected_ingestion))

        assert_called_exactly(Andi.Schemas.AuditEvents.log_audit_event(:api, ingestion_update(), expected_ingestion), 1)
      end
    end

    test "PUT /api/ creating a ingestion with a set id returns a 400", %{conn: conn} do
      %{id: id} = smrt_ingestion = TDG.create_ingestion(%{})
      ingestion = smrt_ingestion |> struct_to_map_with_string_keys()

      with_mocks([
        {IngestionStore, [], [get: fn(^id) -> {:ok, nil} end]},
        {Brook.Event, [], [send: fn(@instance_name, _, _, _) -> :ok end]},
        {DatasetStore, [], [get: fn(_) -> {:ok, %{}} end]}
      ]) do
        conn = put(conn, @route, ingestion)
        body = json_response(conn, 400)
        assert "Do not include id in create call" =~ Map.get(body, "errors")
      end
    end

    test "PUT /api/ updating an ingestion returns a 201 when an ingestion with that ID is found in the store", %{conn: conn} do
      %{id: id} = smrt_ingestion = TDG.create_ingestion(%{})
      ingestion = smrt_ingestion |> struct_to_map_with_string_keys()

      with_mocks([
        {IngestionStore, [], [get: fn(^id) -> {:ok, ingestion} end]},
        {Brook.Event, [], [send: fn(@instance_name, _, _, _) -> :ok end]},
        {DatasetStore, [], [get: fn(_) -> {:ok, %{}} end]}
      ]) do
        conn = put(conn, @route, ingestion)

        response(conn, 201)

        assert_called(Brook.Event.send(@instance_name, ingestion_update(), :andi, smrt_ingestion))

        assert_called_exactly(Andi.Schemas.AuditEvents.log_audit_event(:api, ingestion_update(), smrt_ingestion), 1)
      end
    end

    @tag capture_log: true
    test "PUT /api/ without data returns 500", %{conn: conn} do
      conn = put(conn, @route)
      assert json_response(conn, 500) =~ "Unable to process your request"
    end

    @tag capture_log: true
    test "PUT /api/ with improperly shaped data returns 500", %{conn: conn} do
      conn = put(conn, @route, %{"foobar" => 5, "operational" => 2})
      assert json_response(conn, 500) =~ "Unable to process your request"
    end

    test "PUT /api/ targetDatasets must exist in the datastore", %{conn: conn} do
      smrt_ingestion = TDG.create_ingestion(%{targetDatasets: ["nonexistent_dataset"]})
      {_, ingestion_without_id} = smrt_ingestion |> struct_to_map_with_string_keys() |> Map.pop("id")

      with_mocks([
        {IngestionStore, [], [get: fn(_) -> {:ok, nil} end]},
        {Brook.Event, [], [send: fn(@instance_name, _, _, _) -> :ok end]},
        {DatasetStore, [], [get: fn("nonexistent_dataset") -> {:ok, nil} end]}
      ]) do
        conn = put(conn, @route, ingestion_without_id)
        body = json_response(conn, 400)
        assert "Target dataset does not exist" =~ Map.get(body, "errors")
      end
    end

    test "PUT /api/ fail validation when datasetStore fails", %{conn: conn} do
      %{id: id} = smrt_ingestion = TDG.create_ingestion(%{targetDatasets: ["error_dataset"]})
      ingestion = smrt_ingestion |> struct_to_map_with_string_keys()

      with_mocks([
        {IngestionStore, [], [get: fn(^id) -> {:ok, ingestion} end]},
        {Brook.Event, [], [send: fn(@instance_name, _, _, _) -> :ok end]},
        {DatasetStore, [], [get: fn("error_dataset") -> {:error, "error reason"} end]}
      ]) do
        conn = put(conn, @route, ingestion)
        body = json_response(conn, 400)
        assert "Unable to retrieve target dataset" =~ Map.get(body, "errors")
      end
    end
  end

  defp struct_to_map_with_string_keys(dataset) do
    dataset
    |> Jason.encode!()
    |> Jason.decode!()
  end

  defp get_example_ingestions() do
    example_ingestion_1 = TDG.create_ingestion(%{})

    example_ingestion_1 =
      example_ingestion_1
      |> struct_to_map_with_string_keys()

    example_ingestion_2 = TDG.create_ingestion(%{})

    example_ingestion_2 =
      example_ingestion_2
      |> struct_to_map_with_string_keys()

    [example_ingestion_1, example_ingestion_2]
  end
end
