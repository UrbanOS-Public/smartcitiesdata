defmodule EventHandlerTest do
  @moduledoc false

  use ExUnit.Case

  alias SmartCity.TestDataGenerator, as: TDG
  import SmartCity.Event, only: [data_ingest_end: 0, dataset_delete: 0]
  import Andi, only: [instance_name: 0]
  alias Andi.InputSchemas.Datasets
  alias Andi.TelemetryHelper

  use Placebo

  test "Andi records completed ingestions" do
    dataset = TDG.create_dataset(%{})
    allow(Datasets.update_ingested_time(any(), any()), return: nil)
    expect(TelemetryHelper.add_event_count(any()), return: :ok)
    Brook.Test.send(instance_name(), data_ingest_end(), :andi, dataset)

    assert_called Datasets.update_ingested_time(dataset.id, any())
  end

  test "should delete the view state when dataset delete event is called" do
    dataset = TDG.create_dataset(%{id: Faker.UUID.v4()})
    allow(Brook.ViewState.delete(any(), any()), return: :ok)
    allow(Datasets.delete(any()), return: {:ok, "good"})
    expect(TelemetryHelper.add_event_count(any()), return: :ok)

    Brook.Event.new(type: dataset_delete(), data: dataset, author: :author)
    |> Andi.EventHandler.handle_event()

    assert_called Datasets.delete(dataset.id)
  end
end
