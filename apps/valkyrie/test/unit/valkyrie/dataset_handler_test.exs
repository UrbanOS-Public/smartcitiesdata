defmodule Valkyrie.DatasetHandlerTest do
  use ExUnit.Case
  use Placebo

  alias SmartCity.TestDataGenerator, as: TDG
  alias Valkyrie.{DatasetHandler, TopicManager}

  setup do
    allow DynamicSupervisor.start_child(any(), any()), return: {:ok, :pid}

    :ok
  end

  test "sets up the topics correctly" do
    allow TopicManager.setup_topics(any()), return: %{input_topic: "input", output_topic: "output"}

    dataset = TDG.create_dataset(id: "ds1", technical: %{sourceType: "ingest"})

    DatasetHandler.handle_dataset(dataset)

    assert_called TopicManager.setup_topics(dataset)
  end

  test "ignores remote datasets" do
    allow TopicManager.setup_topics(any()), return: :ignore

    %{id: "1", technical: %{sourceType: "remote"}}
    |> TDG.create_dataset()
    |> DatasetHandler.handle_dataset()

    refute_called TopicManager.setup_topics(any())
  end
end
