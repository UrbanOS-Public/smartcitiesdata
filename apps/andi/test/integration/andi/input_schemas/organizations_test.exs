defmodule Andi.InputSchemas.OrganizationsTest do
  use ExUnit.Case
  use Andi.DataCase

  @moduletag shared_data_connection: true

  alias Andi.InputSchemas.Organization
  alias Andi.InputSchemas.Organizations
  alias SmartCity.TestDataGenerator, as: TDG

  describe "get/1" do
    test "returns a saved dataset by id" do
      org = TDG.create_organization([])

      org
      |> Organization.changeset()
      |> Organizations.save()

      assert nil != Organizations.get(org.id)
    end
  end

  describe "get_all/0" do
    test "gets all organizations in the system" do
      org1 = TDG.create_organization([])
      org2 = TDG.create_organization([])

      andi_orgs =
        Enum.map([org1, org2], fn org ->
          {:ok, andi_org} =
            org
            |> Organization.changeset()
            |> Organizations.save()

          andi_org
        end)

      assert Enum.at(andi_orgs, 0) in Organizations.get_all()
      assert Enum.at(andi_orgs, 1) in Organizations.get_all()
    end
  end

  describe "get_all_harvested_datasets/1" do
    test "gets all harvested datasets in the system for a given org id" do
      org_id = "95254592-d611-4bcb-9478-7fa248f4118d"

      harvested_dataset_one = %{
        "orgId" => org_id
      }

      harvested_dataset_two = %{
        "orgId" => org_id
      }

      harvested_dataset_three = %{
        "orgId" => "blah"
      }

      assert {:ok, harvested_dataset1} = Organizations.update_harvested_dataset(harvested_dataset_one)
      assert {:ok, harvested_dataset2} = Organizations.update_harvested_dataset(harvested_dataset_two)
      assert {:ok, harvested_dataset3} = Organizations.update_harvested_dataset(harvested_dataset_three)

      datasets_for_org = Organizations.get_all_harvested_datasets(org_id)

      assert harvested_dataset1 in datasets_for_org
      assert harvested_dataset2 in datasets_for_org
      refute harvested_dataset3 in datasets_for_org
    end
  end

  describe "get_harvested_dataset/1" do
    test "given an existing harvested dataset, it returns it" do
      harvested_dataset_one = %{
        "orgId" => "95254592-d611-4bcb-9478-7fa248f4118d"
      }

      {:ok, harvested_dataset} = Organizations.update_harvested_dataset(harvested_dataset_one)

      assert %{orgId: "95254592-d611-4bcb-9478-7fa248f4118d"} = Organizations.get_harvested_dataset(harvested_dataset.id)
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
