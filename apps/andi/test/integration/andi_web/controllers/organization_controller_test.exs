defmodule Andi.OrganizationControllerTest do
  use ExUnit.Case
  use Andi.DataCase
  use Placebo
  use Tesla

  @moduletag shared_data_connection: true

  alias SmartCity.Organization
  alias SmartCity.TestDataGenerator, as: TDG
  alias Andi.Services.OrgStore
  alias Andi.InputSchemas.Organizations
  import SmartCity.TestHelper, only: [eventually: 1]

  @instance_name Andi.instance_name()

  plug Tesla.Middleware.BaseUrl, "http://localhost:4000"

  describe "failure to send new organization to event stream" do
    setup do
      allow(Brook.Event.send(@instance_name, any(), :andi, any()),
        return: {:error, :reason},
        meck_options: [:passthrough]
      )

      org = organization(%{orgName: "unhappyPath"})
      {:ok, response} = create(org)
      [unhappy_path: org, response: response]
    end

    test "responds with a 500", %{response: response} do
      assert response.status == 500
    end
  end

  describe "create new organization" do
    test "A new organization is successfully created" do
      org = organization(%{orgName: "test_org"})
      {:ok, response} = create(org)

      assert %Tesla.Env{status: 201} = response
    end

    test "A new org with a non unique id is rejected" do
      org = TDG.create_organization(%{orgName: "non_unique_name"})
      Organizations.update(org)

      new_org = organization(%{orgName: "come_on_man", id: org.id})

      {:ok, response} = create(new_org)

      assert %Tesla.Env{status: 500} = response
    end

    test "A new org with a non unique system name is rejected" do
      org = TDG.create_organization(%{orgName: "non_unique_name"})
      Organizations.update(org)

      new_org = organization(%{orgName: "non_unique_name"})

      {:ok, response} = create(new_org)

      assert %Tesla.Env{status: 500} = response
    end
  end

  describe "user organization associate" do
    setup do
      org = organization()
      {:ok, response} = create(org)
      {:ok, happy_path} = Organization.new(response.body)

      eventually(fn ->
        {:ok, %Organization{}} = OrgStore.get(org.id)
      end)

      [happy_path: happy_path, response: response]
    end

    test "happy path", %{happy_path: org} do
      users = [1, 2]
      body = Jason.encode!(%{org_id: org.id, users: users})

      {:ok, %Tesla.Env{status: 200}} =
        post("/api/v1/organization/#{org.id}/users/add", body, headers: [{"content-type", "application/json"}])

      eventually(fn ->
        assert get_brook(org.id, :org_to_users) == {:ok, MapSet.new(users)}
        assert get_brook(1, :user_to_orgs) == {:ok, MapSet.new([org.id])}
        assert get_brook(2, :user_to_orgs) == {:ok, MapSet.new([org.id])}
      end)
    end
  end

  defp create(org) do
    struct = Jason.encode!(org)

    response = post("/api/v1/organization", struct, headers: [{"content-type", "application/json"}])

    response
  end

  defp organization(overrides \\ %{}) do
    overrides
    |> TDG.create_organization()
    |> Map.from_struct()
  end

  defp get_brook(id, collection) do
    Brook.get(@instance_name, collection, id)
  end
end
