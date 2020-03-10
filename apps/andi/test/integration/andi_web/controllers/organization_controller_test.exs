defmodule Andi.CreateOrgTest do
  use ExUnit.Case
  use Divo
  use Placebo
  use Tesla

  alias SmartCity.Organization
  alias SmartCity.TestDataGenerator, as: TDG
  alias Andi.DatasetStore
  import SmartCity.TestHelper, only: [eventually: 1]
  import Andi

  plug Tesla.Middleware.BaseUrl, "http://localhost:4000"

  describe "failure to send new organization to event stream" do
    setup do
      allow(Brook.Event.send(instance_name(), any(), :andi, any()),
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

  describe "user organization associate" do
    setup do
      org = organization()
      {:ok, response} = create(org)
      {:ok, happy_path} = Organization.new(response.body)

      eventually(fn ->
        {:ok, %Organization{}} = DatasetStore.get_org(org.id)
      end)

      [happy_path: happy_path, response: response]
    end

    test "happy path", %{happy_path: org} do
      users = [1, 2]
      body = Jason.encode!(%{org_id: org.id, users: users})

      {:ok, %Tesla.Env{status: 200}} =
        post("/api/v1/organization/#{org.id}/users/add", body, headers: [{"content-type", "application/json"}])

      eventually(fn ->
        assert Brook.get(instance_name(), :org_to_users, org.id) == {:ok, MapSet.new(users)}
        assert Brook.get(instance_name(), :user_to_orgs, 1) == {:ok, MapSet.new([org.id])}
        assert Brook.get(instance_name(), :user_to_orgs, 2) == {:ok, MapSet.new([org.id])}
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
end
