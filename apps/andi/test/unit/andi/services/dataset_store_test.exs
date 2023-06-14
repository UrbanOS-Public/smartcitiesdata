defmodule Andi.Services.DatasetStoreTest do
  use ExUnit.Case

  import Mock

  alias SmartCity.TestDataGenerator, as: TDG
  alias Andi.Services.DatasetStore

  describe "update/1" do
    test "gets dataset event from Brook" do
      %{id: id} = dataset = TDG.create_dataset(%{})

      with_mock(Brook.ViewState, [merge: fn(:dataset, id, dataset) -> :ok end]) do
        assert :ok == DatasetStore.update(dataset)
      end
    end

    test "returns an error when brook returns an error" do
      expected_error = {:error, "bad things"}
      %{id: id} = dataset = TDG.create_dataset(%{})

      with_mock(Brook.ViewState, [merge: fn(:dataset, id, dataset) -> expected_error end]) do
        assert expected_error == DatasetStore.update(dataset)
      end
    end
  end

  describe "get/1" do
    test "gets dataset event from Brook" do
      %{id: id} = expected_dataset = TDG.create_dataset(%{})
      instance_name = Andi.instance_name()

      with_mock(Brook, [get: fn(instance_name, :dataset, id) -> expected_dataset end]) do
        assert expected_dataset == DatasetStore.get(id)
      end
    end

    test "returns an error when brook returns an error" do
      expected_error = {:error, "bad things"}
      instance_name = Andi.instance_name()

      with_mock(Brook, [get: fn(instance_name, :dataset, "some-id") -> expected_error end]) do
        assert expected_error == DatasetStore.get("some-id")
      end
    end
  end

  describe "get_all/0" do
    test "retrieves all events from Brook" do
      dataset1 = TDG.create_dataset(%{})
      dataset2 = TDG.create_dataset(%{})
      expected_datasets = {:ok, [dataset1, dataset2]}
      instance_name = Andi.instance_name()

      with_mock(Brook, [get_all_values: fn(instance_name, :dataset) -> expected_datasets end]) do
        assert expected_datasets == DatasetStore.get_all()
      end
    end

    test "returns an error when brook returns an error" do
      expected_error = {:error, "bad things"}
      instance_name = Andi.instance_name()

      with_mock(Brook, [get_all_values: fn(instance_name, :dataset) -> expected_error end]) do
        assert expected_error == DatasetStore.get_all()
      end
    end
  end

  describe "get_all!/0" do
    test "raises the error returned by brook" do
      expected_error = "bad things"
      instance_name = Andi.instance_name()

      with_mock(Brook, [get_all_values!: fn(instance_name, :dataset) -> expected_error end]) do
        assert expected_error == DatasetStore.get_all!()
      end
    end
  end

  describe "delete/1" do
    test "deletes dataset event from Brook" do
      with_mock(Brook.ViewState, [delete: fn(:dataset, "some-id") -> :ok end]) do
        assert :ok == DatasetStore.delete("some-id")
      end
    end

    test "returns an error when brook returns an error" do
      expected_error = {:error, "bad things"}
      with_mock(Brook.ViewState, [delete: fn(:dataset, "some-id") -> expected_error end]) do
        assert expected_error == DatasetStore.delete("some-id")
      end
    end
  end
end
