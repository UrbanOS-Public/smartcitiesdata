defmodule Andi.CreateOrgTest do
  use ExUnit.Case
  use Divo
  use Placebo
  use Tesla

  alias SmartCity.Registry.Organization, as: RegOrganization
  alias SmartCity.TestDataGenerator, as: TDG
  import Andi

  plug Tesla.Middleware.BaseUrl, "http://localhost:4000"

  @ou Application.get_env(:andi, :ldap_env_ou)

  setup_all do
    user = Application.get_env(:andi, :ldap_user)
    pass = Application.get_env(:andi, :ldap_pass)
    Paddle.authenticate(user, pass)

    Paddle.add([ou: @ou], objectClass: ["top", "organizationalunit"], ou: @ou)

    org = organization()
    {:ok, response} = create(org)
    [happy_path: org, response: response]
  end

  # Delete after event stream integration is complete
  describe "failure to persist new organization" do
    setup do
      allow(RegOrganization.write(any()), return: {:error, :reason}, meck_options: [:passthrough])
      org = organization(%{orgName: "unhappyPath"})
      {:ok, response} = create(org)
      [unhappy_path: org, response: response]
    end

    test "responds with a 500", %{response: response} do
      assert response.status == 500
    end

    test "removes organization from LDAP", %{unhappy_path: expected} do
      assert {:error, :noSuchObject} = Paddle.get(filter: [cn: expected.orgName, ou: @ou])
    end
  end

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

    test "removes organization from LDAP", %{unhappy_path: expected} do
      assert {:error, :noSuchObject} = Paddle.get(filter: [cn: expected.orgName, ou: @ou])
    end
  end

  defp create(org) do
    struct = Jason.encode!(org)

    post("/api/v1/organization", struct, headers: [{"content-type", "application/json"}])
  end

  defp organization(overrides \\ %{}) do
    overrides
    |> TDG.create_organization()
    |> Map.from_struct()
    |> Map.delete(:id)
  end
end
