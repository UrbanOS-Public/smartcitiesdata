defmodule Andi.DatasetStoreTest do
  use ExUnit.Case
  use Placebo

  import SmartCity.Event, only: [dataset_update: 0]

  alias SmartCity.TestDataGenerator, as: TDG
  alias Andi.DatasetStore

  @brook_instance :andi

  describe "get_all/0" do
    test "retrieves all events from Brook" do
      dataset1 = TDG.create_dataset(%{})
      dataset2 = TDG.create_dataset(%{})
      expected_datasets = {:ok, [dataset1, dataset2]}
      Brook.Event.send(@brook_instance, dataset_update(), :dataset, dataset1)
      Brook.Event.send(@brook_instance, dataset_update(), :dataset, dataset2)

      allow(Brook.get_all_values(@brook_instance, :dataset), return: expected_datasets)

      assert expected_datasets == DatasetStore.get_all()
    end

    test "returns an error when brook returns an error" do
      expected = {:error, "bad things"}
      allow(DatasetStore.get_all(), return: expected)
      actual = DatasetStore.get_all()

      assert expected == actual
    end
  end

  describe "get_all!/0" do
    test "raises the error returned by brook" do
      reason = "bad things"
      allow(Brook.get_all_values(@brook_instance, :dataset), return: {:error, reason})

      assert_raise RuntimeError, reason, fn ->
        DatasetStore.get_all!()
      end
    end
  end
end
