defmodule EventHandlerTest do
  @moduledoc false

  use ExUnit.Case

  alias SmartCity.TestDataGenerator, as: TDG
  import SmartCity.Event, only: [data_ingest_end: 0]
  import Andi, only: [instance_name: 0]

  test "Andi records completed ingestions" do
    dataset = TDG.create_dataset(%{})

    Brook.Test.send(instance_name(), data_ingest_end(), :andi, dataset)

    result = Brook.get!(instance_name(), :ingest_complete, dataset.id)
    assert not is_nil(result)
  end
end
