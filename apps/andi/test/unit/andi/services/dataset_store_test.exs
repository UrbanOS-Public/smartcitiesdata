defmodule Andi.Services.DatasetStoreTest do
  use ExUnit.Case
  use Placebo

  alias SmartCity.TestDataGenerator, as: TDG
  alias Andi.Services.DatasetStore

  describe "update/1" do
    test "gets dataset event from Brook" do
      dataset = TDG.create_dataset(%{id: "dataset-id"})
      allow(Brook.ViewState.merge(:dataset, dataset.id, dataset), return: :ok)
      assert :ok == DatasetStore.update(dataset)
    end

    test "returns an error when brook returns an error" do
      expected_error = {:error, "bad things"}
      dataset = TDG.create_dataset(%{id: "dataset-id"})
      allow(Brook.ViewState.merge(:dataset, dataset.id, dataset), return: expected_error)
      assert expected_error == DatasetStore.update(dataset)
    end
  end

  describe "get/1" do
    test "gets dataset event from Brook" do
      expected_dataset = TDG.create_dataset(%{id: "dataset-id"})
      allow(Brook.get(Andi.instance_name(), :dataset, expected_dataset.id), return: expected_dataset)
      assert expected_dataset == DatasetStore.get(expected_dataset.id)
    end

    test "returns an error when brook returns an error" do
      expected_error = {:error, "bad things"}
      allow(Brook.get(Andi.instance_name(), :dataset, "some-id"), return: expected_error)
      assert expected_error == DatasetStore.get("some-id")
    end
  end

  describe "get_all/0" do
    test "retrieves all events from Brook" do
      dataset1 = TDG.create_dataset(%{})
      dataset2 = TDG.create_dataset(%{})
      expected_datasets = {:ok, [dataset1, dataset2]}
      allow(Brook.get_all_values(Andi.instance_name(), :dataset), return: expected_datasets)
      assert expected_datasets == DatasetStore.get_all()
    end

    test "returns an error when brook returns an error" do
      expected_error = {:error, "bad things"}
      allow(Brook.get_all_values(Andi.instance_name(), :dataset), return: expected_error)
      assert expected_error == DatasetStore.get_all()
    end
  end

  describe "get_all!/0" do
    test "raises the error returned by brook" do
      expected_error = "bad things"
      allow(Brook.get_all_values!(Andi.instance_name(), :dataset), return: expected_error)
      assert expected_error == DatasetStore.get_all!()
    end
  end

  describe "delete/1" do
    test "deletes dataset event from Brook" do
      allow(Brook.ViewState.delete(:dataset, "some-id"), return: :ok)
      assert :ok == DatasetStore.delete("some-id")
    end

    test "returns an error when brook returns an error" do
      expected_error = {:error, "bad things"}
      allow(Brook.ViewState.delete(:dataset, "some-id"), return: expected_error)
      assert expected_error == DatasetStore.delete("some-id")
    end
  end
end
