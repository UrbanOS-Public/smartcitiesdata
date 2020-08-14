defmodule Andi.InputSchemas.OrganizationsTest do
  use ExUnit.Case
  use Andi.DataCase

  alias SmartCity.TestDataGenerator, as: TDG
  alias Andi.InputSchemas.Organizations

  describe "get_all/0" do
    test "gets all harvested datasets in the system" do
      harvested_dataset_one = %{
        "orgId" => "95254592-d611-4bcb-9478-7fa248f4118d"
      }

      harvested_dataset_two = %{
        "orgId" => "95254592-d611-4bcb-9478-7fa248f4118d"
      }

      assert {:ok, _} = Organizations.update_harvested_dataset(harvested_dataset_one)
      assert {:ok, _} = Organizations.update_harvested_dataset(harvested_dataset_two)

      assert [%{orgId: "95254592-d611-4bcb-9478-7fa248f4118d"} | _] = Organizations.get_all()
    end
  end

  describe "get/1" do
    test "given an existing harvested dataset, it returns it" do
      harvested_dataset_one = %{
        "orgId" => "95254592-d611-4bcb-9478-7fa248f4118d"
      }

      {:ok, harvested_dataset} = Organizations.update_harvested_dataset(harvested_dataset_one)

      assert %{orgId: "95254592-d611-4bcb-9478-7fa248f4118d"} = Organizations.get(harvested_dataset.id)
    end
  end
end
