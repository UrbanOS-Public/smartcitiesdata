defmodule DiscoveryApi.OrganizationUpdateTest do
  use ExUnit.Case
  use Divo
  use DiscoveryApi.DataCase
  import SmartCity.TestHelper
  alias DiscoveryApi.TestDataGenerator, as: TDG
  alias DiscoveryApi.Test.Helper

  setup_all do
    Helper.wait_for_brook_to_be_ready()
    :ok
  end

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

    DiscoveryApi.Data.DatasetEventListener.handle_dataset(expected_registry_dataset)

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
        assert persisted_model.organizationDetails.dn == expected_organization.dn
      end,
      2000,
      10
    )
  end
end
