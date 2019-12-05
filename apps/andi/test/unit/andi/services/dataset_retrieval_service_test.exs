defmodule Andi.Services.DatasetRetrievalTest do
  use ExUnit.Case
  use Placebo

  import SmartCity.Event, only: [dataset_update: 0]

  alias SmartCity.TestDataGenerator, as: TDG
  alias Andi.Services.DatasetRetrieval

  @brook_instance :andi_test_brook_or_whatever

  setup do
    brook_config =
      :andi
      |> Application.get_env(:brook)
      |> Keyword.put(:instance, @brook_instance)

    start_supervised!({Brook, brook_config})

    :ok
  end

  describe "get_all/0" do
    test "retrieves all events from Brook" do
      dataset1 = TDG.create_dataset(%{})
      dataset2 = TDG.create_dataset(%{})

      Brook.Event.send(@brook_instance, dataset_update(), :andi, dataset1)
      Brook.Event.send(@brook_instance, dataset_update(), :andi, dataset2)

      assert {:ok, datasets} = DatasetRetrieval.get_all(@brook_instance)

      assert length(datasets) == 2
      assert Enum.member?(datasets, dataset1)
      assert Enum.member?(datasets, dataset2)
    end

    test "returns an error when brook returns an error" do
      expected = {:error, "bad things"}
      allow(Brook.get_all_values(@brook_instance, :dataset), return: expected)

      actual = DatasetRetrieval.get_all(@brook_instance)

      assert expected == actual
    end
  end

  describe "get_all!/0" do
    test "raises the error returned by brook" do
      reason = "bad things"
      allow(Brook.get_all_values(@brook_instance, :dataset), return: {:error, reason})

      assert_raise RuntimeError, reason, fn ->
        DatasetRetrieval.get_all!(@brook_instance)
      end
    end
  end
end
