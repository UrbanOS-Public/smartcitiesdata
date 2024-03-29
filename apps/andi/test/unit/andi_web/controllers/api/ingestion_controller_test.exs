defmodule AndiWeb.API.IngestionControllerTest do
  use AndiWeb.Test.AuthConnCase.UnitCase
  use Placebo

  @route "/api/v1/ingestion"
  @get_ingestions_route "/api/v1/ingestions"
  alias SmartCity.TestDataGenerator, as: TDG
  alias Andi.Services.IngestionStore
  alias Andi.Services.DatasetStore

  import SmartCity.Event, only: [ingestion_delete: 0, ingestion_update: 0]

  @instance_name Andi.instance_name()

  setup do
    allow(Andi.Schemas.AuditEvents.log_audit_event(any(), any(), any()), return: %{})
    example_ingestion_1 = TDG.create_ingestion(%{})

    example_ingestion_1 =
      example_ingestion_1
      |> struct_to_map_with_string_keys()

    example_ingestion_2 = TDG.create_ingestion(%{})

    example_ingestion_2 =
      example_ingestion_2
      |> struct_to_map_with_string_keys()

    example_ingestions = [example_ingestion_1, example_ingestion_2]

    allow(IngestionStore.get_all(),
      return: {:ok, example_ingestions},
      meck_options: [:passthrough]
    )

    allow(Brook.Event.send(@instance_name, any(), :andi, any()),
      return: :ok,
      meck_options: [:passthrough]
    )

    uuid = Faker.UUID.v4()

    allow(DatasetStore.get("dataset_id"), return: {:ok, %{id: "dataset_id"}})

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

    {:ok, request: request, message: message, example_ingestions: example_ingestions}
  end

  describe "GET /ingestions" do
    @tag capture_log: true
    test "returns a 200", %{conn: conn, example_ingestions: example_ingestions} do
      response = get(conn, @get_ingestions_route)

      actual_ingestions =
        response
        |> json_response(200)

      assert MapSet.new(example_ingestions) == MapSet.new(actual_ingestions)
    end

    test "returns a 404", %{conn: conn} do
      allow(IngestionStore.get_all(),
        return: {:error, "this was an error"},
        meck_options: [:passthrough]
      )

      response = get(conn, @get_ingestions_route)

      parsed_response =
        response
        |> json_response(404)

      assert parsed_response == "Unable to process your request"
    end
  end

  describe "GET /ingestion:id" do
    @tag capture_log: true
    test "returns a 200", %{conn: conn} do
      ingestion = TDG.create_ingestion(%{})
      allow(IngestionStore.get(ingestion.id), return: {:ok, ingestion})

      conn = get(conn, "/api/v1/ingestion/#{ingestion.id}")

      response = conn |> json_response(200)
      assert Map.get(response, "id") == ingestion.id
    end

    test "returns a 404", %{conn: conn} do
      ingestion = TDG.create_ingestion(%{})
      allow(IngestionStore.get(ingestion.id), return: {:ok, nil})

      conn = get(conn, "/api/v1/ingestion/#{ingestion.id}")

      response = conn |> json_response(404)

      assert response == "Ingestion not found"
    end

    test "returns a 404 when an error is thrown by the IngestionStore", %{conn: conn} do
      allow(IngestionStore.get_all(),
        return: {:error, "this was an error"},
        meck_options: [:passthrough]
      )

      response = get(conn, @get_ingestions_route)

      parsed_response =
        response
        |> json_response(404)

      assert parsed_response == "Unable to process your request"
    end
  end

  describe "POST /ingestion/delete" do
    setup %{} do
      ingestion = TDG.create_ingestion(%{})
      [ingestion: ingestion]
    end

    test "should send ingestion:delete event", %{conn: conn, ingestion: ingestion} do
      allow(IngestionStore.get(any()), return: {:ok, ingestion})
      allow(Brook.Event.send(@instance_name, any(), any(), any()), return: :ok)

      post(conn, "#{@route}/delete", %{id: ingestion.id})
      |> json_response(200)

      assert_called(Brook.Event.send(@instance_name, ingestion_delete(), :andi, ingestion))

      assert_called(
        Andi.Schemas.AuditEvents.log_audit_event(:api, ingestion_delete(), ingestion),
        once()
      )
    end

    @tag capture_log: true
    test "does not send ingestion:delete event if ingestion does not exist", %{
      conn: conn,
      ingestion: ingestion
    } do
      allow(IngestionStore.get(any()), return: {:ok, nil})
      allow(Brook.Event.send(@instance_name, any(), any(), any()), return: :ok)

      post(conn, "#{@route}/delete", %{id: ingestion.id})
      |> json_response(404)

      refute_called(Brook.Event.send(@instance_name, ingestion_delete(), :andi, ingestion))
    end

    @tag capture_log: true
    test "handles error", %{conn: conn, ingestion: ingestion} do
      allow(IngestionStore.get(any()), return: {:ok, ingestion})

      allow(Brook.Event.send(@instance_name, any(), any(), any()),
        return: {:error, "Mistakes were made"}
      )

      post(conn, "#{@route}/delete", %{id: ingestion.id})
      |> json_response(500)
    end
  end

  describe "PUT /ingestion" do
    test "PUT /api/ with data returns a 201", %{conn: conn} do
      smrt_ingestion = TDG.create_ingestion(%{})
      {_, ingestion_without_id} = smrt_ingestion |> struct_to_map_with_string_keys() |> Map.pop("id")

      allow(Brook.Event.send(@instance_name, any(), any(), any()), return: :ok)
      allow(Andi.InputSchemas.Datasets.get(any()), return: %{technical: %{sourceType: "ingest"}})
      allow(DatasetStore.get(any()), return: {:ok, %{}})
      conn = put(conn, @route, ingestion_without_id)

      {_, decoded_body} = Jason.decode(response(conn, 201))

      expected_ingestion = TDG.create_ingestion(Map.put(ingestion_without_id, "id", decoded_body["id"]))

      assert_called(Brook.Event.send(@instance_name, ingestion_update(), :andi, expected_ingestion))

      assert_called(
        Andi.Schemas.AuditEvents.log_audit_event(:api, ingestion_update(), expected_ingestion),
        once()
      )
    end

    test "PUT /api/ creating a ingestion with a set id returns a 400", %{conn: conn} do
      smrt_ingestion = TDG.create_ingestion(%{})
      ingestion = smrt_ingestion |> struct_to_map_with_string_keys()

      allow(Brook.Event.send(@instance_name, any(), any(), any()), return: :ok)
      allow(DatasetStore.get(any()), return: {:ok, %{}})
      allow(IngestionStore.get(Map.get(ingestion, "id")), return: {:ok, nil})

      conn = put(conn, @route, ingestion)
      body = json_response(conn, 400)
      assert "Do not include id in create call" =~ Map.get(body, "errors")
    end

    test "PUT /api/ updating an ingestion returns a 201 when an ingestion with that ID is found in the store", %{conn: conn} do
      smrt_ingestion = TDG.create_ingestion(%{})
      ingestion = smrt_ingestion |> struct_to_map_with_string_keys()

      allow(Brook.Event.send(@instance_name, any(), any(), any()), return: :ok)
      allow(DatasetStore.get(any()), return: {:ok, %{}})
      allow(IngestionStore.get(Map.get(ingestion, "id")), return: {:ok, ingestion})

      conn = put(conn, @route, ingestion)

      response(conn, 201)

      assert_called(Brook.Event.send(@instance_name, ingestion_update(), :andi, smrt_ingestion))

      assert_called(
        Andi.Schemas.AuditEvents.log_audit_event(:api, ingestion_update(), smrt_ingestion),
        once()
      )
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

      allow(Brook.Event.send(@instance_name, any(), any(), any()), return: :ok)
      allow(IngestionStore.get(any()), return: {:ok, nil})
      allow(DatasetStore.get("nonexistent_dataset"), return: {:ok, nil})

      conn = put(conn, @route, ingestion_without_id)
      body = json_response(conn, 400)
      assert "Target dataset does not exist" =~ Map.get(body, "errors")
    end

    test "PUT /api/ fail validation when datasetStore fails", %{conn: conn} do
      smrt_ingestion = TDG.create_ingestion(%{targetDatasets: ["error_dataset"]})
      ingestion = smrt_ingestion |> struct_to_map_with_string_keys()

      allow(Brook.Event.send(@instance_name, any(), any(), any()), return: :ok)
      allow(IngestionStore.get(Map.get(ingestion, "id")), return: {:ok, ingestion})
      allow(DatasetStore.get("error_dataset"), return: {:error, "error reason"})

      conn = put(conn, @route, ingestion)
      body = json_response(conn, 400)
      assert "Unable to retrieve target dataset" =~ Map.get(body, "errors")
    end
  end

  defp struct_to_map_with_string_keys(dataset) do
    dataset
    |> Jason.encode!()
    |> Jason.decode!()
  end
end
