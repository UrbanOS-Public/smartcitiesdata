defmodule AndiWeb.API.DatasetControllerTest do
  use AndiWeb.Test.AuthConnCase.UnitCase

  alias SmartCity.TestDataGenerator, as: TDG
  alias Andi.Services.DatasetStore
  alias Andi.InputSchemas.InputConverter

  import Mock
  import SmartCity.Event, only: [dataset_disable: 0, dataset_delete: 0, dataset_update: 0]

  @instance_name Andi.instance_name()
  @route "/api/v1/dataset"
  @get_datasets_route "/api/v1/datasets"

  setup_with_mocks([
    {Andi.Schemas.AuditEvents, [], [log_audit_event: fn _, _, _ -> %{} end]},
    {Brook.Event, [:passthrough], [send: fn @instance_name, _, :andi, _ -> :ok end]}
  ]) do
    {:ok, example_datasets: get_example_datasets()}
  end

  describe "POST /dataset/disable" do
    setup %{} do
      dataset = TDG.create_dataset(%{})
      [dataset: dataset]
    end

    test "should send dataset:disable event", %{conn: conn, dataset: dataset} do
      with_mocks([
        {DatasetStore, [], [get: fn _ -> {:ok, dataset} end]},
        {Brook.Event, [], [send: fn @instance_name, _, _, _ -> :ok end]}
      ]) do
        post(conn, "#{@route}/disable", %{id: dataset.id})
        |> json_response(200)

        assert_called(Brook.Event.send(@instance_name, dataset_disable(), :andi, dataset))
      end
    end

    @tag capture_log: true
    test "does not send dataset:disable event if dataset does not exist", %{
      conn: conn,
      dataset: dataset
    } do
      with_mocks([
        {DatasetStore, [], [get: fn _ -> {:ok, nil} end]},
        {Brook.Event, [], [send: fn @instance_name, _, _, _ -> :ok end]}
      ]) do
        post(conn, "#{@route}/disable", %{id: dataset.id})
        |> json_response(404)

        assert_not_called(Brook.Event.send(@instance_name, dataset_disable(), :andi, dataset))
      end
    end

    @tag capture_log: true
    test "handles error", %{conn: conn, dataset: dataset} do
      with_mocks([
        {DatasetStore, [], [get: fn _ -> {:ok, dataset} end]},
        {Brook.Event, [], [send: fn @instance_name, _, _, _ -> {:error, "Mistakes were made"} end]}
      ]) do
        post(conn, "#{@route}/disable", %{id: dataset.id})
        |> json_response(500)
      end
    end
  end

  describe "POST /dataset/delete" do
    setup %{} do
      dataset = TDG.create_dataset(%{})
      [dataset: dataset]
    end

    test "should send dataset:delete event", %{conn: conn, dataset: dataset} do
      with_mocks([
        {DatasetStore, [], [get: fn _ -> {:ok, dataset} end]},
        {Brook.Event, [], [send: fn @instance_name, _, _, _ -> :ok end]}
      ]) do
        post(conn, "#{@route}/delete", %{id: dataset.id})
        |> json_response(200)

        assert_called(Brook.Event.send(@instance_name, dataset_delete(), :andi, dataset))

        assert_called_exactly(Andi.Schemas.AuditEvents.log_audit_event(:api, dataset_delete(), dataset), 1)
      end
    end

    @tag capture_log: true
    test "does not send dataset:delete event if dataset does not exist", %{
      conn: conn,
      dataset: dataset
    } do
      with_mocks([
        {DatasetStore, [], [get: fn _ -> {:ok, nil} end]},
        {Brook.Event, [], [send: fn @instance_name, _, _, _ -> :ok end]}
      ]) do
        post(conn, "#{@route}/delete", %{id: dataset.id})
        |> json_response(404)

        assert_not_called(Brook.Event.send(@instance_name, dataset_delete(), :andi, dataset))

        assert_not_called(Andi.Schemas.AuditEvents.log_audit_event(:api, dataset_delete(), dataset))
      end
    end

    @tag capture_log: true
    test "handles error", %{conn: conn, dataset: dataset} do
      with_mocks([
        {DatasetStore, [], [get: fn _ -> {:ok, dataset} end]},
        {Brook.Event, [], [send: fn @instance_name, _, _, _ -> {:error, "Mistakes were made"} end]}
      ]) do
        post(conn, "#{@route}/delete", %{id: dataset.id})
        |> json_response(500)
      end
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

  test "PUT /api/ with data returns a 201", %{conn: conn} do
    dataset = TDG.create_dataset(%{}) |> struct_to_map_with_string_keys()

    {_, dataset_without_id} = dataset |> Map.pop("id")

    with_mocks([
      {InputConverter, [], [smrt_dataset_to_full_changeset: fn _ -> %{valid?: true} end]},
      {Brook.Event, [], [send: fn @instance_name, _, _, _ -> :ok end]}
    ]) do
      conn = put(conn, @route, dataset_without_id)

      {_, decoded_body} = Jason.decode(response(conn, 201))
      expected_dataset = TDG.create_dataset(Map.put(dataset_without_id, "id", decoded_body["id"]))

      assert_called(Brook.Event.send(@instance_name, dataset_update(), :andi, expected_dataset))

      assert_called_exactly(Andi.Schemas.AuditEvents.log_audit_event(:api, dataset_update(), expected_dataset), 1)
    end
  end

  @tag capture_log: true
  test "PUT /api/ creating a dataset with a set id returns a 400", %{conn: conn} do
    dataset = TDG.create_dataset(%{}) |> struct_to_map_with_string_keys()

    with_mocks([
      {InputConverter, [], [smrt_dataset_to_full_changeset: fn _ -> %{valid?: true} end]},
      {Brook.Event, [], [send: fn @instance_name, _, _, _ -> :ok end]}
    ]) do
      conn = put(conn, @route, dataset)

      response(conn, 400)
      assert_not_called(Brook.Event.send(:_, :_, :andi, :_))
      assert_not_called(Andi.Schemas.AuditEvents.log_audit_event(:api, :_, :_))
    end
  end

  @tag capture_log: true
  test "PUT /api/ updating an ingestion returns a 201 when an ingestion with that ID is found in the store", %{conn: conn} do
    smrt_dataset = TDG.create_dataset(%{})
    %{"id" => id} = dataset = smrt_dataset |> struct_to_map_with_string_keys()

    with_mocks([
      {DatasetStore, [], [get: fn id -> {:ok, dataset} end]},
      {InputConverter, [], [smrt_dataset_to_full_changeset: fn _ -> %{valid?: true} end]},
      {Brook.Event, [], [send: fn @instance_name, _, _, _ -> :ok end]}
    ]) do
      conn = put(conn, @route, dataset)

      response(conn, 201)

      assert_called(Brook.Event.send(@instance_name, dataset_update(), :andi, smrt_dataset))
      assert_called_exactly(Andi.Schemas.AuditEvents.log_audit_event(:api, dataset_update(), smrt_dataset), 1)
    end
  end

  describe "GET dataset definitions from /api/dataset/" do
    @tag capture_log: true
    test "returns a 200", %{conn: conn, example_datasets: example_datasets} do
      with_mock(DatasetStore, [:passthrough], get_all: fn -> {:ok, example_datasets} end) do
        actual_datasets =
          get(conn, @get_datasets_route)
          |> json_response(200)

        assert MapSet.new(example_datasets) == MapSet.new(actual_datasets)
      end
    end
  end

  describe "GET /api/dataset/:dataset_id" do
    test "should return a given dataset when it exists", %{conn: conn} do
      %{id: id} = dataset = TDG.create_dataset(%{})

      with_mock(DatasetStore, get: fn id -> {:ok, dataset} end) do
        conn = get(conn, "/api/v1/dataset/#{id}")

        response = conn |> json_response(200)
        assert Map.get(response, "id") == id
      end
    end

    test "should return a 404 when requested dataset does not exist", %{conn: conn} do
      with_mock(DatasetStore, get: fn _ -> {:ok, nil} end) do
        conn = get(conn, "/api/v1/dataset/123")

        assert 404 == conn.status
      end
    end
  end

  defp struct_to_map_with_string_keys(dataset) do
    dataset
    |> Jason.encode!()
    |> Jason.decode!()
  end

  defp get_example_datasets() do
    example_dataset_1 = TDG.create_dataset(%{})

    example_dataset_1 =
      example_dataset_1
      |> struct_to_map_with_string_keys()

    example_dataset_2 = TDG.create_dataset(%{})

    example_dataset_2 =
      example_dataset_2
      |> struct_to_map_with_string_keys()

    [example_dataset_1, example_dataset_2]
  end
end
