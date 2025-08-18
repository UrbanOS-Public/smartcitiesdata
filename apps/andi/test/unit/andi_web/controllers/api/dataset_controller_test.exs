defmodule AndiWeb.API.DatasetControllerTest do
  use AndiWeb.Test.AuthConnCase.UnitCase

  alias SmartCity.TestDataGenerator, as: TDG
  alias Andi.Services.DatasetStore
  alias Andi.InputSchemas.InputConverter

  import SmartCity.Event, only: [dataset_disable: 0, dataset_delete: 0, dataset_update: 0]

  @moduletag timeout: 5000

  @instance_name Andi.instance_name()
  @route "/api/v1/dataset"
  @get_datasets_route "/api/v1/datasets"

  setup do
    # Set up :meck for modules without dependency injection
    modules_to_mock = [Andi.Schemas.AuditEvents, Brook.Event]
    
    # Clean up any existing mocks first
    Enum.each(modules_to_mock, fn module ->
      try do
        :meck.unload(module)
      catch
        _, _ -> :ok
      end
    end)
    
    # Set up fresh mocks
    Enum.each(modules_to_mock, fn module ->
      try do
        :meck.new(module, [:passthrough])
      catch
        :error, {:already_started, _} -> :ok
      end
    end)
    
    # Default expectations
    :meck.expect(Andi.Schemas.AuditEvents, :log_audit_event, fn _, _, _ -> %{} end)
    :meck.expect(Brook.Event, :send, fn @instance_name, _, :andi, _ -> :ok end)
    
    on_exit(fn ->
      Enum.each(modules_to_mock, fn module ->
        try do
          :meck.unload(module)
        catch
          _, _ -> :ok
        end
      end)
    end)
    
    {:ok, example_datasets: get_example_datasets()}
  end

  describe "POST /dataset/disable" do
    setup %{} do
      dataset = TDG.create_dataset(%{})
      [dataset: dataset]
    end

    test "should send dataset:disable event", %{conn: conn, dataset: dataset} do
      # Set up mocks for this test
      try do
        :meck.new(DatasetStore, [:passthrough])
      catch
        :error, {:already_started, _} -> :ok
      end
      
      :meck.expect(DatasetStore, :get, fn _ -> {:ok, dataset} end)
      :meck.expect(Brook.Event, :send, fn @instance_name, _, _, _ -> :ok end)
      
      post(conn, "#{@route}/disable", %{id: dataset.id})
      |> json_response(200)

      assert :meck.num_calls(Brook.Event, :send, [@instance_name, dataset_disable(), :andi, dataset]) == 1
      
      :meck.unload(DatasetStore)
    end

    @tag capture_log: true
    test "does not send dataset:disable event if dataset does not exist", %{
      conn: conn,
      dataset: dataset
    } do
      # Set up mocks for this test
      try do
        :meck.new(DatasetStore, [:passthrough])
      catch
        :error, {:already_started, _} -> :ok
      end
      
      :meck.expect(DatasetStore, :get, fn _ -> {:ok, nil} end)
      :meck.expect(Brook.Event, :send, fn @instance_name, _, _, _ -> :ok end)
      
      post(conn, "#{@route}/disable", %{id: dataset.id})
      |> json_response(404)

      assert :meck.num_calls(Brook.Event, :send, [@instance_name, dataset_disable(), :andi, dataset]) == 0
      
      :meck.unload(DatasetStore)
    end

    @tag capture_log: true
    test "handles error", %{conn: conn, dataset: dataset} do
      # Set up mocks for this test
      try do
        :meck.new(DatasetStore, [:passthrough])
      catch
        :error, {:already_started, _} -> :ok
      end
      
      :meck.expect(DatasetStore, :get, fn _ -> {:ok, dataset} end)
      :meck.expect(Brook.Event, :send, fn @instance_name, _, _, _ -> {:error, "Mistakes were made"} end)
      
      post(conn, "#{@route}/disable", %{id: dataset.id})
      |> json_response(500)
      
      :meck.unload(DatasetStore)
    end
  end

  describe "POST /dataset/delete" do
    setup %{} do
      dataset = TDG.create_dataset(%{})
      [dataset: dataset]
    end

    test "should send dataset:delete event", %{conn: conn, dataset: dataset} do
      # Set up mocks for this test
      try do
        :meck.new(DatasetStore, [:passthrough])
      catch
        :error, {:already_started, _} -> :ok
      end
      
      :meck.expect(DatasetStore, :get, fn _ -> {:ok, dataset} end)
      :meck.expect(Brook.Event, :send, fn @instance_name, _, _, _ -> :ok end)
      
      post(conn, "#{@route}/delete", %{id: dataset.id})
      |> json_response(200)

      assert :meck.num_calls(Brook.Event, :send, [@instance_name, dataset_delete(), :andi, dataset]) == 1
      assert :meck.num_calls(Andi.Schemas.AuditEvents, :log_audit_event, [:api, dataset_delete(), dataset]) == 1
      
      :meck.unload(DatasetStore)
    end

    @tag capture_log: true
    test "does not send dataset:delete event if dataset does not exist", %{
      conn: conn,
      dataset: dataset
    } do
      # Set up mocks for this test
      try do
        :meck.new(DatasetStore, [:passthrough])
      catch
        :error, {:already_started, _} -> :ok
      end
      
      :meck.expect(DatasetStore, :get, fn _ -> {:ok, nil} end)
      :meck.expect(Brook.Event, :send, fn @instance_name, _, _, _ -> :ok end)
      
      post(conn, "#{@route}/delete", %{id: dataset.id})
      |> json_response(404)

      assert :meck.num_calls(Brook.Event, :send, [@instance_name, dataset_delete(), :andi, dataset]) == 0
      assert :meck.num_calls(Andi.Schemas.AuditEvents, :log_audit_event, [:api, dataset_delete(), dataset]) == 0
      
      :meck.unload(DatasetStore)
    end

    @tag capture_log: true
    test "handles error", %{conn: conn, dataset: dataset} do
      # Set up mocks for this test
      try do
        :meck.new(DatasetStore, [:passthrough])
      catch
        :error, {:already_started, _} -> :ok
      end
      
      :meck.expect(DatasetStore, :get, fn _ -> {:ok, dataset} end)
      :meck.expect(Brook.Event, :send, fn @instance_name, _, _, _ -> {:error, "Mistakes were made"} end)
      
      post(conn, "#{@route}/delete", %{id: dataset.id})
      |> json_response(500)
      
      :meck.unload(DatasetStore)
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

    # Set up mocks for this test
    try do
      :meck.new(InputConverter, [:passthrough])
    catch
      :error, {:already_started, _} -> :ok
    end
    
    :meck.expect(InputConverter, :smrt_dataset_to_full_changeset, fn _ -> %{valid?: true} end)
    :meck.expect(Brook.Event, :send, fn @instance_name, _, _, _ -> :ok end)
    
    conn = put(conn, @route, dataset_without_id)

    {_, decoded_body} = Jason.decode(response(conn, 201))
    expected_dataset = TDG.create_dataset(Map.put(dataset_without_id, "id", decoded_body["id"]))

    assert :meck.num_calls(Brook.Event, :send, [@instance_name, dataset_update(), :andi, expected_dataset]) == 1
    assert :meck.num_calls(Andi.Schemas.AuditEvents, :log_audit_event, [:api, dataset_update(), expected_dataset]) == 1
    
    :meck.unload(InputConverter)
  end

  @tag capture_log: true
  test "PUT /api/ creating a dataset with a set id returns a 400", %{conn: conn} do
    dataset = TDG.create_dataset(%{}) |> struct_to_map_with_string_keys()

    # Set up mocks for this test
    try do
      :meck.new(InputConverter, [:passthrough])
    catch
      :error, {:already_started, _} -> :ok
    end
    
    :meck.expect(InputConverter, :smrt_dataset_to_full_changeset, fn _ -> %{valid?: true} end)
    :meck.expect(Brook.Event, :send, fn @instance_name, _, _, _ -> :ok end)
    
    conn = put(conn, @route, dataset)

    response(conn, 400)
    # For these wildcard assertions, we check that Brook.Event.send and log_audit_event were not called with any arguments
    assert :meck.num_calls(Brook.Event, :send, :_) == 0
    assert :meck.num_calls(Andi.Schemas.AuditEvents, :log_audit_event, :_) == 0
    
    :meck.unload(InputConverter)
  end

  @tag capture_log: true
  test "PUT /api/ updating an ingestion returns a 201 when an ingestion with that ID is found in the store", %{conn: conn} do
    smrt_dataset = TDG.create_dataset(%{})
    %{"id" => _id} = dataset = smrt_dataset |> struct_to_map_with_string_keys()

    # Set up mocks for this test
    try do
      :meck.new(DatasetStore, [:passthrough])
    catch
      :error, {:already_started, _} -> :ok
    end
    
    try do
      :meck.new(InputConverter, [:passthrough])
    catch
      :error, {:already_started, _} -> :ok
    end
    
    :meck.expect(DatasetStore, :get, fn _id -> {:ok, dataset} end)
    :meck.expect(InputConverter, :smrt_dataset_to_full_changeset, fn _ -> %{valid?: true} end)
    :meck.expect(Brook.Event, :send, fn @instance_name, _, _, _ -> :ok end)
    
    conn = put(conn, @route, dataset)

    response(conn, 201)

    assert :meck.num_calls(Brook.Event, :send, [@instance_name, dataset_update(), :andi, smrt_dataset]) == 1
    assert :meck.num_calls(Andi.Schemas.AuditEvents, :log_audit_event, [:api, dataset_update(), smrt_dataset]) == 1
    
    :meck.unload(DatasetStore)
    :meck.unload(InputConverter)
  end

  describe "GET dataset definitions from /api/dataset/" do
    @tag capture_log: true
    test "returns a 200", %{conn: conn, example_datasets: example_datasets} do
      # Set up mocks for this test
      try do
        :meck.new(DatasetStore, [:passthrough])
      catch
        :error, {:already_started, _} -> :ok
      end
      
      :meck.expect(DatasetStore, :get_all, fn -> {:ok, example_datasets} end)
      
      actual_datasets =
        get(conn, @get_datasets_route)
        |> json_response(200)

      assert MapSet.new(example_datasets) == MapSet.new(actual_datasets)
      
      :meck.unload(DatasetStore)
    end
  end

  describe "GET /api/dataset/:dataset_id" do
    test "should return a given dataset when it exists", %{conn: conn} do
      %{id: id} = dataset = TDG.create_dataset(%{})

      # Set up mocks for this test
      try do
        :meck.new(DatasetStore, [:passthrough])
      catch
        :error, {:already_started, _} -> :ok
      end
      
      :meck.expect(DatasetStore, :get, fn ^id -> {:ok, dataset} end)
      
      conn = get(conn, "/api/v1/dataset/#{id}")

      response = conn |> json_response(200)
      assert Map.get(response, "id") == id
      
      :meck.unload(DatasetStore)
    end

    test "should return a 404 when requested dataset does not exist", %{conn: conn} do
      # Set up mocks for this test
      try do
        :meck.new(DatasetStore, [:passthrough])
      catch
        :error, {:already_started, _} -> :ok
      end
      
      :meck.expect(DatasetStore, :get, fn _ -> {:ok, nil} end)
      
      conn = get(conn, "/api/v1/dataset/123")

      assert 404 == conn.status
      
      :meck.unload(DatasetStore)
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
