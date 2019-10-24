defmodule Andi.Services.OrganizationReposterTest do
  use ExUnit.Case
  use Placebo
  import Andi
  import SmartCity.Event, only: [organization_update: 0]

  alias Andi.Services.OrganizationReposter
  alias SmartCity.TestDataGenerator, as: TDG

  @tag capture_log: true
  test "errors when registry cannot get all values" do
    error = {:error, "Bad things happened"}
    allow(SmartCity.Registry.Organization.get_all(), return: error)
    assert OrganizationReposter.repost_all_orgs() == error
  end

  @tag capture_log: true
  test "errors when brook cannot send an update" do
    allow(SmartCity.Registry.Organization.get_all(),
      return: {:ok, [SmartCity.TestDataGenerator.create_organization(%{})]}
    )

    allow(Brook.Event.send(any(), any(), :andi, any()), return: {:error, "does not matter"})
    assert OrganizationReposter.repost_all_orgs() == {:error, "Failed to repost all organizations"}
  end

  test "reposts organizations from registry as organization updates" do
    organization = SmartCity.TestDataGenerator.create_organization(%{})
    registry_organization = organization |> Map.from_struct() |> SmartCity.Registry.Organization.new() |> elem(1)
    allow(SmartCity.Registry.Organization.get_all(), return: {:ok, [registry_organization]})
    allow(Brook.Event.send(any(), any(), :andi, any()), return: :ok)

    assert OrganizationReposter.repost_all_orgs() == :ok

    expect(Brook.Event.send(instance_name(), organization_update(), :andi, organization))
  end
end
