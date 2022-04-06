defmodule AndiWeb.AccessGroupLiveView.DatasetTableTest do
  use AndiWeb.Test.AuthConnCase.UnitCase
  use Placebo
  alias Andi.Schemas.User

  import Phoenix.LiveViewTest
  import FlokiHelpers, only: [get_text: 2]

  alias SmartCity.TestDataGenerator, as: TDG
  alias Andi.InputSchemas.AccessGroups
  alias Andi.InputSchemas.AccessGroup

  @endpoint AndiWeb.Endpoint
  @url_path "/access-groups"
  @user UserHelpers.create_user()

  defp allowAuthUser do
    allow(Andi.Repo.get_by(Andi.Schemas.User, any()), return: @user)
    allow(User.get_all(), return: [@user])
    allow(User.get_by_subject_id(any()), return: @user)
  end

  setup do
    allowAuthUser()
    []
  end

  setup %{auth_conn_case: auth_conn_case} do
    auth_conn_case.disable_revocation_list.()
    :ok
  end

  describe "Basic associated datasets table load" do
    test "shows \"No Associated Datasets\" when there are no rows to show", %{conn: conn} do
      access_group = setup_access_group()
      allow(Andi.Repo.preload(any(), any()), return: %{datasets: [], users: []})

      assert {:ok, view, html} = live(conn, "#{@url_path}/#{access_group.id}")

      assert get_text(html, ".access-groups-sub-table__cell") =~ "No Associated Datasets"
    end

    test "shows an associated dataset", %{conn: conn} do
      access_group = setup_access_group()
      dataset = TDG.create_dataset(%{})
      allow(Andi.Repo.preload(any(), any()), return: %{datasets: [%{id: dataset.id}], users: []})
      allow(Andi.InputSchemas.Datasets.get(dataset.id), return: dataset)

      assert {:ok, view, html} = live(conn, "#{@url_path}/#{access_group.id}")

      assert get_text(html, ".access-groups-sub-table__cell") =~ dataset.business.dataTitle
    end

    test "shows multiple associated datasets", %{conn: conn} do
      access_group = setup_access_group()
      dataset_1 = TDG.create_dataset(%{})
      dataset_2 = TDG.create_dataset(%{})
      allow(Andi.Repo.preload(any(), any()), return: %{datasets: [%{id: dataset_1.id}, %{id: dataset_2.id}], users: []})
      allow(Andi.InputSchemas.Datasets.get(dataset_1.id), return: dataset_1)
      allow(Andi.InputSchemas.Datasets.get(dataset_2.id), return: dataset_2)

      assert {:ok, view, html} = live(conn, "#{@url_path}/#{access_group.id}")

      assert get_text(html, ".access-groups-sub-table__cell") =~ dataset_1.business.dataTitle
      assert get_text(html, ".access-groups-sub-table__cell") =~ dataset_2.business.dataTitle
    end

    test "shows a remove button for each dataset", %{conn: conn} do
      access_group = setup_access_group()
      dataset_1 = TDG.create_dataset(%{})
      dataset_2 = TDG.create_dataset(%{})
      allow(Andi.Repo.preload(any(), any()), return: %{datasets: [%{id: dataset_1.id}, %{id: dataset_2.id}], users: []})
      allow(Andi.InputSchemas.Datasets.get(dataset_1.id), return: dataset_1)
      allow(Andi.InputSchemas.Datasets.get(dataset_2.id), return: dataset_2)

      assert {:ok, view, html} = live(conn, "#{@url_path}/#{access_group.id}")
      text = get_text(html, ".access-groups-sub-table__cell")
      results = Regex.scan(~r/Remove/, text)

      assert length(results) == 2
    end

    defp setup_access_group() do
      access_group = TDG.create_access_group(%{})
      allow(AccessGroups.update(any()), return: %AccessGroup{id: access_group.id, name: access_group.name})
      allow(AccessGroups.get(any()), return: %AccessGroup{id: access_group.id, name: access_group.name})
      allow(Andi.InputSchemas.AccessGroup.changeset(any(), any()), return: AccessGroup.changeset(access_group))
      allow(Andi.Repo.get(Andi.InputSchemas.AccessGroup, any()), return: [])
      access_group
    end
  end
end
