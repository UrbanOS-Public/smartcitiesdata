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

  describe "update_harvested_dataset/1" do
    test "Only datasets with unique sourceId are added to the system" do
      harvested_dataset_one = %{
        "orgId" => "9525d4592-d61d1-4dbcb-94f78-7fa2f48f4118d",
        "sourceId" => "12345"
      }

      harvested_dataset_two = %{
        "orgId" => "9525d4592-d61d1-4dbcb-94f78-7fa2f48f4118d",
        "sourceId" => "12345"
      }

      assert {:ok, _} = Organizations.update_harvested_dataset(harvested_dataset_one)
      assert {:error, _} = Organizations.update_harvested_dataset(harvested_dataset_two)

      assert [%{orgId: "9525d4592-d61d1-4dbcb-94f78-7fa2f48f4118d"}] = Organizations.get_all()
    end
  end

  describe "get_harvested_dataset/1" do
    test "harvested dataset is returned when getting by sourceId" do
      harvested_dataset_one = %{
        "orgId" => "9525d4592-d61d1-4dbcb-94f78-7fa2f48f4118d",
        "sourceId" => "12345"
      }

      assert {:ok, _} = Organizations.update_harvested_dataset(harvested_dataset_one)

      assert %{sourceId: "12345"} = Organizations.get_harvested_dataset("12345")
    end

    test "no datasets are returned that havent been harvested" do
      harvested_dataset_one = %{
        "orgId" => "9525d4592-d61d1-4dbcb-94f78-7fa2f48f4118d",
        "sourceId" => "12345"
      }

      assert {:ok, _} = Organizations.update_harvested_dataset(harvested_dataset_one)

      assert nil == Organizations.get_harvested_dataset("notthere")
    end
  end
end
