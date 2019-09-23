defmodule Forklift.InitTest do
  use ExUnit.Case
  use Placebo

  import SmartCity.TestHelper
  alias Forklift.Datasets.DatasetHandler

  test "loads all forklift schemas and starts an ingestion for them" do
    allow Brook.get_all_values!(:forklift, :datasets_to_process), return: [:dataset1, :dataset2, :dataset3]
    allow DatasetHandler.start_dataset_ingest(any()), return: :ok

    {:ok, pid} = Forklift.Init.start_link([])

    eventually(fn ->
      assert_called Brook.get_all_values!(:forklift, :datasets_to_process)
      assert_called DatasetHandler.start_dataset_ingest(:dataset1)
      assert_called DatasetHandler.start_dataset_ingest(:dataset2)
      assert_called DatasetHandler.start_dataset_ingest(:dataset3)
      assert num_calls(DatasetHandler.start_dataset_ingest(any())) == 3
      assert false == Process.alive?(pid)
    end)
  end
end
