defmodule EventHandlerTest do
  @moduledoc false

  use ExUnit.Case

  alias SmartCity.TestDataGenerator, as: TDG
  import SmartCity.Event, only: [data_ingest_end: 0, dataset_delete: 0]
  import Andi, only: [instance_name: 0]

  use Placebo

  test "Andi records completed ingestions" do
    dataset = TDG.create_dataset(%{})

    Brook.Test.send(instance_name(), data_ingest_end(), :andi, dataset)

    result = Brook.get!(instance_name(), :ingested_time, dataset.id)

    assert not is_nil(result)
  end

  test "should delete the view state when dataset delete event is called" do
    dataset = TDG.create_dataset(%{id: Faker.UUID.v4()})
    allow(Brook.ViewState.delete(any(), any()), return: :ok)

    Brook.Event.new(type: dataset_delete(), data: dataset, author: :author)
    |> Andi.EventHandler.handle_event()

    assert :ok = Andi.DatasetUtil.delete(dataset.id)
  end
end
