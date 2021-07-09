defmodule AndiWeb.AccessLevelTest do
  use ExUnit.Case
  use Andi.DataCase
  use AndiWeb.Test.AuthConnCase.IntegrationCase
  import Phoenix.LiveViewTest

  alias SmartCity.TestDataGenerator, as: TDG

  alias Andi.InputSchemas.Datasets
  alias Andi.Services.DatasetStore
  alias Andi.InputSchemas.Organizations
  alias Andi.Services.OrgStore

  setup_all do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Andi.Repo)
    Ecto.Adapters.SQL.Sandbox.mode(Andi.Repo, {:shared, self()})

    organization = create_organization()
    dataset = create_dataset(organization.id)
    deletable_dataset = create_dataset(organization.id)

    [
      dataset_id: dataset.id,
      deletable_dataset_id: deletable_dataset.id,
      organization_id: organization.id
    ]
  end

  use AndiWeb.Test.PublicAccessCase

  describe "supervision" do
    test "does not start brook" do
      refute Brook.Supervisor in andi_children()
    end

    test "does not start elsa" do
      refute Elsa.Supervisor in andi_children()
    end
  end

  describe "API" do
    test "does not allow GET access to datasets via API", %{curator_conn: conn, dataset_id: id} do
      assert get(conn, "/api/v1/dataset/#{id}")
             |> response(404)
    end

    test "does not allow PUT access to datasets via API", %{curator_conn: conn, dataset_id: id} do
      assert put(conn, "/api/v1/dataset", %{id: id})
             |> response(404)
    end

    test "does not allow POST access to datasets delete API", %{curator_conn: conn, deletable_dataset_id: id} do
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

  describe "administrative features in UI" do
    test "does not allow access to organizations list", %{curator_conn: conn} do
      assert get(conn, "/organizations")
             |> response(404)
    end

    test "does not allow access to organization edit", %{curator_conn: conn, organization_id: id} do
      assert get(conn, "/organizations/#{id}")
             |> response(404)
    end

    test "does not allow access to 'Edit View' for a dataset", %{curator_conn: conn, dataset_id: id} do
      assert get(conn, "/datasets/#{id}")
             |> response(404)
    end
  end

  describe "submitter features in UI" do
    test "allows functioning access to the 'Dataset List View'", %{curator_conn: conn} do
      assert {:ok, _view, _html} = live(conn, "/datasets")
    end
  end

  defp andi_children() do
    Supervisor.which_children(Andi.Supervisor)
    |> Enum.map(&elem(&1, 0))
  end

  defp create_organization() do
    organization = TDG.create_organization(%{})

    Organizations.update(organization)

    Brook.Test.with_event(Andi.instance_name(), fn ->
      OrgStore.update(organization)
    end)

    organization
  end

  defp create_dataset(org_id) do
    dataset = TDG.create_dataset(%{organization_id: org_id})

    Datasets.update(dataset)

    Brook.Test.with_event(Andi.instance_name(), fn ->
      DatasetStore.update(dataset)
    end)

    dataset
  end
end
