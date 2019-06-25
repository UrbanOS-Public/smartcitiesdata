defmodule Valkyrie.DatasetHandlerTest do
  use ExUnit.Case
  use Placebo

  alias SmartCity.TestDataGenerator, as: TDG
  alias Valkyrie.{Dataset, DatasetHandler, TopicManager}

  setup do
    Cachex.clear(Dataset.cache_name())
    :ok
  end

  test "ignores remote datasets" do
    allow TopicManager.create_and_subscribe(any()), return: :ignore

    %{id: "1", technical: %{sourceType: "remote"}}
    |> TDG.create_dataset()
    |> DatasetHandler.handle_dataset()

    refute_called TopicManager.create_and_subscribe(any())
  end

  test "handle_dataset/1 will store dataset schema in Dataset" do
    dataset = TDG.create_dataset(id: "ds1")

    allow TopicManager.create_and_subscribe(any()), return: :does_not_matter

    DatasetHandler.handle_dataset(dataset)

    assert_called TopicManager.create_and_subscribe("raw-#{dataset.id}")
  end
end
