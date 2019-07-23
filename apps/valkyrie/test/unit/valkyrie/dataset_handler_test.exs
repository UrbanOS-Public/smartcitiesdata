defmodule Valkyrie.DatasetHandlerTest do
  use ExUnit.Case
  use Placebo
  import Checkov

  alias SmartCity.TestDataGenerator, as: TDG
  alias Valkyrie.{DatasetHandler, TopicManager}

  setup do
    allow DynamicSupervisor.start_child(any(), any()), return: {:ok, :pid}

    :ok
  end

  data_test "sets up the topics correctly for dataset with sourceType #{sourceType}" do
    allow TopicManager.setup_topics(any()), return: %{input_topic: "input", output_topic: "output"}

    dataset = TDG.create_dataset(id: dataset_id, technical: %{sourceType: sourceType})

    DatasetHandler.handle_dataset(dataset)

    assert_called TopicManager.setup_topics(dataset)

    where(
      dataset_id: ["ds1", "ds2"],
      sourceType: ["ingest", "stream"]
    )
  end

  test "ignores remote datasets" do
    allow TopicManager.setup_topics(any()), return: :ignore

    %{id: "1", technical: %{sourceType: "remote"}}
    |> TDG.create_dataset()
    |> DatasetHandler.handle_dataset()

    refute_called TopicManager.setup_topics(any())
  end
end
