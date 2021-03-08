defmodule DiscoveryApi.Event.EventHandlerTest do
  use ExUnit.Case

  use DiscoveryApi.DataCase
  use DiscoveryApi.ElasticSearchCase

  import SmartCity.TestHelper
  import SmartCity.Event, only: [dataset_update: 0, user_organization_disassociate: 0]

  alias SmartCity.TestDataGenerator, as: TDG
  alias DiscoveryApi.Test.Helper
  alias DiscoveryApi.Data.Model
  alias DiscoveryApi.Search.Elasticsearch
  alias DiscoveryApi.Schemas.Users

  @instance_name DiscoveryApi.instance_name()

  describe "#{dataset_update()}" do
    test "updates the dataset in the search index" do
      organization = Helper.create_persisted_organization()

      dataset = TDG.create_dataset(%{technical: %{orgId: organization.id}})
      dataset_id = dataset.id

      Brook.Event.send(@instance_name, dataset_update(), __MODULE__, dataset)

      eventually(fn ->
        assert {:ok, %Model{id: ^dataset_id}} = Elasticsearch.Document.get(dataset_id)
      end)

      updated_dataset = put_in(dataset, [:business, :dataTitle], "updated title")
      Brook.Event.send(@instance_name, dataset_update(), __MODULE__, updated_dataset)

      eventually(fn ->
        assert {:ok, %Model{id: ^dataset_id, title: "updated title"}} = Elasticsearch.Document.get(dataset_id)
      end)
    end
  end

  describe "organization:update" do
    test "when an organization is updated then it is retrievable" do
      expected_organization = Helper.create_persisted_organization()

      result =
        HTTPoison.get!("http://localhost:4000/api/v1/organization/#{expected_organization.id}", %{})
        |> Map.from_struct()

      assert result.status_code == 200
      new_org = Jason.decode!(result.body, keys: :atoms)

      assert new_org.id == expected_organization.id
      assert new_org.name == expected_organization.orgName
      assert new_org.title == expected_organization.orgTitle
    end

    test "persisting a model should use information from the organization:update event" do
      expected_organization = Helper.create_persisted_organization()
      expected_registry_dataset = TDG.create_dataset(%{technical: %{orgId: expected_organization.id}})

      Brook.Event.send(@instance_name, dataset_update(), __MODULE__, expected_registry_dataset)

      eventually(
        fn ->
          persisted_model = DiscoveryApi.Data.Model.get(expected_registry_dataset.id)
          assert persisted_model != nil
          assert persisted_model.organization == expected_organization.orgTitle
          assert persisted_model.organizationDetails.id == expected_organization.id
          assert persisted_model.organizationDetails.orgName == expected_organization.orgName
          assert persisted_model.organizationDetails.orgTitle == expected_organization.orgTitle
          assert persisted_model.organizationDetails.description == expected_organization.description
          assert persisted_model.organizationDetails.logoUrl == expected_organization.logoUrl
          assert persisted_model.organizationDetails.homepage == expected_organization.homepage
        end,
        2000,
        10
      )
    end
  end

  describe("#{user_organization_disassociate()}") do
    test "removes associated user and organization in ecto" do
      organization = Helper.create_persisted_organization()
      {:ok, user} = Users.create(%{subject_id: "cam", email: "cam@cam.com"})
      Users.associate_with_organization(user.id, organization.id)

      {:ok, user_with_orgs} = Users.get_user_with_organizations(user.id)
      assert Enum.any?(user_with_orgs.organizations, fn org -> org.id == organization.id end)

      {:ok, user_org_disassociation} = SmartCity.UserOrganizationDisassociate.new(%{user_id: user.id, org_id: organization.id})

      Brook.Event.send(@instance_name, user_organization_disassociate(), __MODULE__, user_org_disassociation)

      eventually(fn ->
        {:ok, user_with_orgs} = Users.get_user_with_organizations(user.id)
        assert Enum.all?(user_with_orgs.organizations, fn org -> org.id != organization.id end)
      end)
    end
  end
end
