defmodule AndiWeb.AccessLevelTest do

  use ExUnit.Case
  use Andi.DataCase
  use AndiWeb.Test.AuthConnCase.IntegrationCase

  alias SmartCity.TestDataGenerator, as: TDG

  alias Andi.InputSchemas.Datasets
  alias Andi.Services.DatasetStore
  alias Andi.InputSchemas.Organizations
  alias Andi.Services.OrgStore

  setup_all do
    organization = TDG.create_organization(%{})
    dataset = TDG.create_dataset(%{technical: %{orgId: organization.id}})

    Organizations.update(organization)
    Datasets.update(dataset)

    Brook.Test.with_event(Andi.instance_name(), fn ->
      OrgStore.update(organization)
      DatasetStore.update(dataset)
    end)

    on_exit(fn ->
      Application.put_env(:andi, :access_level, :private)
      Application.ensure_all_started(:andi)
    end)
    Application.put_env(:andi, :access_level, :public)

    Application.stop(:andi)
    Application.stop(:brook)
    Application.stop(:elsa)

    Application.ensure_all_started(:andi)

    [
      dataset_id: dataset.id,
      organization_id: organization.id
    ]
  end

  describe "`:public` access" do
    test "does not start brook" do
      # TODO - test this main supervisor instead
      refute :brook in Application.started_applications()
    end

    test "does not start elsa" do
      # TODO - test this main supervisor instead
      refute :elsa in Application.started_applications()
    end

    test "does not allow GET access to datasets via API", %{curator_conn: conn, dataset_id: id} do
      assert get(conn, "/api/v1/dataset/#{id}")
      |> response(404)
    end

    test "does not allow PUT access to datasets via API", %{curator_conn: conn, dataset_id: id} do
      assert put(conn, "/api/v1/dataset", %{id: id})
      |> response(404)
    end

    test "does not allow POST access to datasets delete API", %{curator_conn: conn, dataset_id: id} do
      assert post(conn, "/api/v1/dataset/delete", %{id: id})
      |> response(404)
    end

    test "does not allow POST access to datasets disable API", %{curator_conn: conn, dataset_id: id} do
      assert post(conn, "/api/v1/dataset/disable", %{id: id})
      |> response(404)
    end

    test "does not allow access to datasets list", %{curator_conn: conn} do
      assert get(conn, "/api/v1/datasets")
      |> response(404)
    end

    test "does not allow access to organizations list", %{curator_conn: conn} do
      assert get(conn, "/api/v1/organizations")
      |> response(404)
    end

    test "does not allow POST access to organizations via API", %{curator_conn: conn, organization_id: id} do
      assert post(conn, "/api/v1/organization", %{id: id})
      |> response(404)
    end

    test "does not allow POST access to organization user association via API", %{curator_conn: conn, organization_id: id} do
      assert post(conn, "/api/v1/organization/#{id}/users/add", %{org_id: id, user: []})
      |> response(404)
    end
  end
end
