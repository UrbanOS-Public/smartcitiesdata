defmodule Andi.InputSchemas.Datasets.DatasetTest do
  use ExUnit.Case
  use Andi.DataCase

  alias SmartCity.TestDataGenerator, as: TDG
  alias Andi.InputSchemas.Datasets
  alias Andi.InputSchemas.Datasets.Dataset
  alias Andi.InputSchemas.AccessGroups
  import SmartCity.TestHelper, only: [eventually: 1]

  @moduletag shared_data_connection: true

  describe "associate_with_access_group/2" do
    setup do
      dataset = TDG.create_dataset(%{})
      {:ok, _andi_dataset} = Datasets.update(dataset)

      access_group = TDG.create_access_group(%{})
      {:ok, _andi_access_group} = AccessGroups.update(access_group)

      %{dataset_id: dataset.id, access_group_id: access_group.id}
    end

    test "associates a dataset with an access group", %{dataset_id: dataset_id, access_group_id: access_group_id} do
      {:ok, dataset} = Dataset.associate_with_access_group(access_group_id, dataset_id)

      eventually(fn ->
        assert [%{id: access_group_id}] = Map.get(dataset, :access_groups)
      end)
    end

    test "a dataset can be associated with multiple access groups", %{dataset_id: dataset_id, access_group_id: access_group_id} do
      access_group_2 = TDG.create_access_group(%{})
      {:ok, _andi_access_group} = AccessGroups.update(access_group_2)

      {:ok, dataset} = Dataset.associate_with_access_group(access_group_id, dataset_id)
      {:ok, dataset} = Dataset.associate_with_access_group(access_group_2.id, dataset_id)

      eventually(fn ->
        assert [%{id: access_group_id}, %{id: access_group_2.id}] = Map.get(dataset, :access_groups)
      end)
    end
  end

  describe "disassociate_with_access_group/2" do
    setup do
      dataset = TDG.create_dataset(%{})
      {:ok, _andi_dataset} = Datasets.update(dataset)

      access_group = TDG.create_access_group(%{})
      {:ok, _andi_access_group} = AccessGroups.update(access_group)

      %{dataset_id: dataset.id, access_group_id: access_group.id}

      {:ok, dataset} = Dataset.associate_with_access_group(access_group_id, dataset_id)

      eventually(fn ->
        assert [%{id: access_group_id}] = Map.get(dataset, :access_groups)
      end)
    end

    test "disassociates a dataset from an access group", %{dataset_id: dataset_id, access_group_id: access_group_id} do
      {:ok, dataset} = Dataset.disassociate_with_access_group(access_group_id, dataset_id)

      eventually(fn ->
        assert [] = Map.get(dataset, :access_groups)
      end)
    end
  end
end
