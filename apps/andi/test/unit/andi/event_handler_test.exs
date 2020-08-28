defmodule EventHandlerTest do
  @moduledoc false

  use ExUnit.Case

  alias SmartCity.TestDataGenerator, as: TDG
  import SmartCity.Event, only: [data_ingest_end: 0, dataset_delete: 0, dataset_harvest_start: 0]
  import Andi, only: [instance_name: 0]
  import SmartCity.TestHelper, only: [eventually: 1]
  alias Andi.InputSchemas.Datasets
  alias Andi.Harvest.Harvester
  alias Andi.InputSchemas.Organizations

  use Placebo

  test "Andi records completed ingestions" do
    dataset = TDG.create_dataset(%{})
    allow(Datasets.update_ingested_time(any(), any()), return: nil)
    expect(TelemetryEvent.add_event_metrics(any(), [:events_handled]), return: :ok)
    Brook.Test.send(instance_name(), data_ingest_end(), :andi, dataset)

    assert_called Datasets.update_ingested_time(dataset.id, any())
  end

  test "should delete the view state when dataset delete event is called" do
    dataset = TDG.create_dataset(%{id: Faker.UUID.v4()})
    allow(Brook.ViewState.delete(any(), any()), return: :ok)
    allow(Datasets.delete(any()), return: {:ok, "good"})
    allow(Organizations.delete_harvested_dataset(any()), return: any())
    expect(TelemetryEvent.add_event_metrics(any(), [:events_handled]), return: :ok)

    Brook.Event.new(type: dataset_delete(), data: dataset, author: :author)
    |> Andi.EventHandler.handle_event()

    assert_called Datasets.delete(dataset.id)
  end

  test "data_harvest_start event triggers harvesting" do
    org = TDG.create_organization(%{})
    allow(Harvester.start_harvesting(any()), return: :ok)

    Brook.Test.send(instance_name(), dataset_harvest_start(), :andi, org)

    eventually(fn ->
      assert_called(Harvester.start_harvesting(org))
    end)
  end
end
