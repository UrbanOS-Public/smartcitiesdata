defmodule Andi.InputSchemas.OrganizationsTest do
  use ExUnit.Case
  use Andi.DataCase

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

  describe "get_all_harvested_datasets/0" do
    test "gets all harvested datasets in the system" do
      harvested_dataset_one = %{
        "orgId" => "95254592-d611-4bcb-9478-7fa248f4118d"
      }

      harvested_dataset_two = %{
        "orgId" => "95254592-d611-4bcb-9478-7fa248f4118d"
      }

      assert {:ok, _} = Organizations.update_harvested_dataset(harvested_dataset_one)
      assert {:ok, _} = Organizations.update_harvested_dataset(harvested_dataset_two)

      assert [%{orgId: "95254592-d611-4bcb-9478-7fa248f4118d"} | _] = Organizations.get_all_harvested_datasets()
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
end
