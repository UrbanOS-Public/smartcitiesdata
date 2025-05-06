defmodule Andi.Event.EventHandlerTest do
  @moduledoc false
  use ExUnit.Case
  use AndiWeb.Test.AuthConnCase.UnitCase

  import SmartCity.Event
  import Mock
  import SmartCity.TestHelper, only: [eventually: 1]

  alias Andi.Event.EventHandler
  alias SmartCity.TestDataGenerator, as: TDG
  alias Andi.InputSchemas.Datasets
  alias Andi.Harvest.Harvester
  alias Andi.InputSchemas.Organizations
  alias Andi.Services.OrgStore
  alias Andi.InputSchemas.Ingestions
  alias Andi.Services.IngestionStore

  @instance_name Andi.instance_name()

  test "should delete the view state and the postgres entry when ingestion delete event is called" do
    ingestion = TDG.create_ingestion(%{id: Faker.UUID.v4()})
    with_mocks([
      {IngestionStore, [], [delete: fn(_) -> :ok end]},
      {Ingestions, [], [delete: fn(_) -> {:ok, "good"} end]}
    ]) do
      :meck.expect(TelemetryEvent, :add_event_metrics, [:_, [:events_handled]], return: :ok)

      Brook.Event.new(type: ingestion_delete(), data: ingestion, author: :author)
      |> EventHandler.handle_event()

      assert_called Ingestions.delete(ingestion.id)
      assert_called IngestionStore.delete(ingestion.id)
    end
  end

  test "should update the view state and the postgres entry when ingestion update event is called" do
    current_time = DateTime.utc_now()

    ingestion =
      TDG.create_ingestion(%{id: Faker.UUID.v4()})
      |> Map.put(:ingestedTime, DateTime.to_iso8601(current_time))

    with_mocks([
      {IngestionStore, [], [update: fn(_) -> :ok end]},
      {Ingestions, [], [update: fn(ingestion) -> {:ok, "good"} end]},
      {DateTime, [:passthrough], [utc_now: fn() -> current_time end]}
    ]) do
      :meck.expect(TelemetryEvent, :add_event_metrics, [:_, [:events_handled]], return: :ok)

      Brook.Event.new(type: ingestion_update(), data: ingestion, author: :author)
      |> EventHandler.handle_event()

      assert_called Ingestions.update(ingestion)
      assert_called IngestionStore.update(ingestion)
    end
  end

  test "should delete the view state when dataset delete event is called" do
    dataset = TDG.create_dataset(%{id: Faker.UUID.v4()})
<<<<<<< HEAD
    allow(Brook.ViewState.delete(any(), any()), return: :ok)
    allow(Datasets.delete(any()), return: {:ok, "good"})
    allow(Organizations.delete_harvested_dataset(any()), return: any())
    allow(Ingestions.get_all(), return: [])
    expect(TelemetryEvent.add_event_metrics(any(), [:events_handled]), return: :ok)
=======
>>>>>>> e0f8e73bdbd46b02183a7f15c4363fd6c2da5e9a

    with_mocks([
      {Brook.ViewState, [], [delete: fn(_, _) -> :ok end]},
      {Datasets, [], [delete: fn(_) -> {:ok, "good"} end]},
      {Organizations, [], [delete_harvested_dataset: fn(_) -> "" end]}
    ]) do
      :meck.expect(TelemetryEvent, :add_event_metrics, [:_, [:events_handled]], return: :ok)

      Brook.Event.new(type: dataset_delete(), data: dataset, author: :author)
      |> EventHandler.handle_event()

      assert_called Datasets.delete(dataset.id)
    end
  end

  test "data_harvest_start event triggers harvesting" do
    org = TDG.create_organization(%{})

    with_mock(Harvester, [start_harvesting: fn(_) -> :ok end]) do
      Brook.Test.send(@instance_name, dataset_harvest_start(), :andi, org)

      eventually(fn ->
        assert_called(Harvester.start_harvesting(org))
      end)
    end
  end

  describe "data harvest event is triggered when organization is updated" do

    setup_with_mocks([
      {Brook.Event, [:passthrough], [
        send: fn
          (@instance_name, dataset_harvest_start(), :andi, _) -> :ok
          (@instance_name, type, :andi, message) -> passthrough([@instance_name, type, :andi, message]) end
      ]},
      {OrgStore, [], [update: fn(_) -> :ok end]},
      {Organizations, [], [update: fn(_) -> :ok end]}
    ]) do
      :ok
    end

    test "data:harvest:start event is triggered" do
      org = TDG.create_organization(%{dataJsonUrl: "www.google.com"})
      Brook.Event.send(@instance_name, organization_update(), :andi, org)

      assert_called_exactly(Brook.Event.send(@instance_name, dataset_harvest_start(), :andi, org), 1)
    end

    test "data:harvest:start event isnt called for orgs missing data json url" do
      org = TDG.create_organization(%{dataJsonUrl: nil})
      Brook.Event.send(@instance_name, organization_update(), :andi, org)

      assert_not_called(Brook.Event.send(@instance_name, dataset_harvest_start(), :andi, org))
    end
  end
end
