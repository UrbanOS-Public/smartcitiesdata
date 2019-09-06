defmodule Valkyrie.DatasetHandlerTest do
  use ExUnit.Case
  use Placebo
  use Brook.Event.Handler
  import Checkov
  import SmartCity.Event, only: [dataset_update: 0]

  alias SmartCity.TestDataGenerator, as: TDG
  alias Valkyrie.DatasetHandler

  describe "handle_event/1" do
    setup do
      allow(Valkyrie.DatasetProcessor.start(any()), return: :does_not_matter)

      :ok
    end

    data_test "Processes datasets with #{source_type} " do
      dataset = TDG.create_dataset(id: "does_not_matter", technical: %{sourceType: source_type})

      DatasetHandler.handle_event(%Brook.Event{type: dataset_update(), data: dataset, author: :author})

      assert called == called?(Valkyrie.DatasetProcessor.start(dataset))

      where([
        [:source_type, :called],
        ["ingest", true],
        ["stream", true],
        ["host", false],
        ["remote", false],
        ["invalid", false]
      ])
    end

    test "Should return :merge when handled" do
      dataset = TDG.create_dataset(id: "does_not_matter", technical: %{sourceType: "ingest"})

      actual = DatasetHandler.handle_event(%Brook.Event{type: dataset_update(), data: dataset, author: :author})

      assert {:merge, :datasets, dataset.id, dataset} == actual
    end
  end
end
