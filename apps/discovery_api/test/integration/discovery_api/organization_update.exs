defmodule DiscoveryApi.OrganizationUpdateTest do
  use ExUnit.Case
  use Divo
  import SmartCity.TestHelper
  import SmartCity.Event, only: [organization_update: 0]
  alias SmartCity.TestDataGenerator, as: TDG

  test "when an organization is updated then it is retrievable" do
    wait_for_brook_to_be_ready()
    DiscoveryApi.ReleaseTasks.migrate()

    expected_organization =
      TDG.create_organization(%{
        id: "11234",
        orgName: "My_little_org",
        orgTitle: "Turtles all the way down"
      })

    Brook.Event.send(DiscoveryApi.instance(), organization_update(), :test, expected_organization)

    eventually(
      fn ->
        organization_from_database =
          DiscoveryApi.Schemas.Organizations.list_organizations()
          |> Enum.find(fn organization -> expected_organization.id == organization.id end)

        assert organization_from_database != nil
      end,
      2000,
      10
    )
  end

  defp wait_for_brook_to_be_ready() do
    Process.sleep(5_000)
  end

  defp get(url, headers \\ %{}) do
    HTTPoison.get!(url, headers)
    |> Map.from_struct()
  end
end
