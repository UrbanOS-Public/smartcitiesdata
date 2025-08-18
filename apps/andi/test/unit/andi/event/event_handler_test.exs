defmodule Andi.Event.EventHandlerTest do
  @moduledoc false
  use ExUnit.Case
  use AndiWeb.Test.AuthConnCase.UnitCase
  import Mox

  import SmartCity.Event
  import SmartCity.TestHelper, only: [eventually: 1]

  alias Andi.Event.EventHandler
  alias SmartCity.TestDataGenerator, as: TDG
  alias Andi.InputSchemas.Datasets
  alias Andi.Harvest.Harvester
  alias Andi.InputSchemas.Organizations
  alias Andi.Services.OrgStore
  alias Andi.InputSchemas.Ingestions
  alias Andi.Services.IngestionStore

  @moduletag timeout: 5000
  @instance_name Andi.instance_name()

  setup :verify_on_exit!
  setup :set_mox_from_context

  test "should delete the view state and the postgres entry when ingestion delete event is called" do
    ingestion = TDG.create_ingestion(%{id: Faker.UUID.v4()})

    # Use :meck for modules without dependency injection
    try do
      :meck.new(IngestionStore, [:passthrough])
      :meck.new(Ingestions, [:passthrough])
    catch
      :error, {:already_started, _} -> :ok
    end

    :meck.expect(IngestionStore, :delete, fn _ -> :ok end)
    :meck.expect(Ingestions, :delete, fn _ -> {:ok, "good"} end)

    Brook.Event.new(type: ingestion_delete(), data: ingestion, author: :author)
    |> EventHandler.handle_event()

    # Verify the calls were made
    assert :meck.called(Ingestions, :delete, [ingestion.id])
    assert :meck.called(IngestionStore, :delete, [ingestion.id])
    
    # Clean up
    try do
      :meck.unload(IngestionStore)
      :meck.unload(Ingestions)
    catch
      _, _ -> :ok
    end
  end

  test "should update the view state and the postgres entry when ingestion update event is called" do
    current_time = DateTime.utc_now()

    ingestion =
      TDG.create_ingestion(%{id: Faker.UUID.v4()})
      |> Map.put(:ingestedTime, DateTime.to_iso8601(current_time))

    # Use :meck for modules without dependency injection
    try do
      :meck.new(IngestionStore, [:passthrough])
      :meck.new(Ingestions, [:passthrough])
      :meck.new(DateTime, [:passthrough])
    catch
      :error, {:already_started, _} -> :ok
    end

    :meck.expect(IngestionStore, :update, fn _ -> :ok end)
    :meck.expect(Ingestions, :update, fn _ingestion -> {:ok, "good"} end)
    :meck.expect(DateTime, :utc_now, fn -> current_time end)

    Brook.Event.new(type: ingestion_update(), data: ingestion, author: :author)
    |> EventHandler.handle_event()

    # Verify the calls were made
    assert :meck.called(Ingestions, :update, [ingestion])
    assert :meck.called(IngestionStore, :update, [ingestion])
    
    # Clean up
    try do
      :meck.unload(IngestionStore)
      :meck.unload(Ingestions)
      :meck.unload(DateTime)
    catch
      _, _ -> :ok
    end
  end

  test "should delete the view state when dataset delete event is called" do
    dataset = TDG.create_dataset(%{id: Faker.UUID.v4()})

    # Use :meck for modules without dependency injection
    try do
      :meck.new(Brook.ViewState, [:passthrough])
      :meck.new(Datasets, [:passthrough])
      :meck.new(Organizations, [:passthrough])
      :meck.new(Ingestions, [:passthrough])
    catch
      :error, {:already_started, _} -> :ok
    end

    :meck.expect(Brook.ViewState, :delete, fn _, _ -> :ok end)
    :meck.expect(Datasets, :delete, fn _ -> {:ok, "good"} end)
    :meck.expect(Organizations, :delete_harvested_dataset, fn _ -> "" end)
    :meck.expect(Ingestions, :get_all, fn -> [] end)

    Brook.Event.new(type: dataset_delete(), data: dataset, author: :author)
    |> EventHandler.handle_event()

    # Verify the calls were made
    assert :meck.called(Datasets, :delete, [dataset.id])
    
    # Clean up
    try do
      :meck.unload(Brook.ViewState)
      :meck.unload(Datasets)
      :meck.unload(Organizations)
      :meck.unload(Ingestions)
    catch
      _, _ -> :ok
    end
  end

  test "data_harvest_start event triggers harvesting" do
    org = TDG.create_organization(%{})

    # Enhanced :meck setup with better error handling
    try do
      :meck.unload(Harvester)
    catch
      _, _ -> :ok
    end
    
    Process.sleep(10)  # Brief pause for cleanup
    
    try do
      :meck.new(Harvester, [:passthrough, :no_link])
    catch
      :error, {:already_started, _} -> 
        :meck.unload(Harvester)
        Process.sleep(10)
        :meck.new(Harvester, [:passthrough, :no_link])
      error, reason ->
        IO.puts("Warning: Mock creation error for Harvester: #{inspect({error, reason})}")
        :ok
    end

    :meck.expect(Harvester, :start_harvesting, fn _ -> :ok end)

    Brook.Test.send(@instance_name, dataset_harvest_start(), :andi, org)

    eventually(fn ->
      assert :meck.called(Harvester, :start_harvesting, [org])
    end)

    # Enhanced cleanup
    try do
      :meck.unload(Harvester)
    catch
      _, _ -> :ok
    end
  end

  describe "data harvest event is triggered when organization is updated" do
    setup do
      # Use :meck for modules without dependency injection
      try do
        :meck.new(Brook.Event, [:passthrough])
        :meck.new(OrgStore, [:passthrough])
        :meck.new(Organizations, [:passthrough])
      catch
        :error, {:already_started, _} -> :ok
      end

      :meck.expect(Brook.Event, :send, fn
        @instance_name, dataset_harvest_start(), :andi, _ -> :ok
        @instance_name, type, :andi, message -> :meck.passthrough([@instance_name, type, :andi, message])
      end)
      :meck.expect(OrgStore, :update, fn _ -> :ok end)
      :meck.expect(Organizations, :update, fn _ -> :ok end)

      on_exit(fn ->
        try do
          :meck.unload(Brook.Event)
          :meck.unload(OrgStore)
          :meck.unload(Organizations)
        catch
          _, _ -> :ok
        end
      end)

      :ok
    end

    test "data:harvest:start event is triggered" do
      org = TDG.create_organization(%{dataJsonUrl: "www.google.com"})
      Brook.Event.send(@instance_name, organization_update(), :andi, org)

      # Allow some time for the event to be processed
      Process.sleep(10)
      
      # Verify the call was made
      assert :meck.called(Brook.Event, :send, [@instance_name, dataset_harvest_start(), :andi, org])
    end

    test "data:harvest:start event isnt called for orgs missing data json url" do
      org = TDG.create_organization(%{dataJsonUrl: nil})
      Brook.Event.send(@instance_name, organization_update(), :andi, org)

      # Allow some time for the event to be processed
      Process.sleep(10)
      
      # Verify the harvest start call was NOT made
      refute :meck.called(Brook.Event, :send, [@instance_name, dataset_harvest_start(), :andi, org])
    end
  end
end
