defmodule AndiWeb.AccessGroupLiveView.DatasetTableTest do
  use AndiWeb.Test.AuthConnCase.UnitCase

  import Mock
  import Phoenix.LiveViewTest
  import FlokiHelpers, only: [get_text: 2]

  alias Andi.Schemas.User
  alias SmartCity.TestDataGenerator, as: TDG
  alias Andi.InputSchemas.AccessGroups
  alias Andi.InputSchemas.AccessGroup

  @endpoint AndiWeb.Endpoint
  @url_path "/access-groups"
  @user UserHelpers.create_user()

  setup_with_mocks([
    {Andi.Repo, [], [get_by: fn(Andi.Schemas.User, _) -> @user end]},
    {User, [], [
      get_all: fn() -> [@user] end,
      get_by_subject_id: fn(_) -> @user end
    ]},
    {Guardian.DB.Token, [], [find_by_claims: fn(_) -> nil end]}
  ]) do
    []
  end

  describe "Basic associated datasets table load" do
    test "shows \"No Associated Datasets\" when there are no rows to show", %{conn: conn} do
      access_group = TDG.create_access_group(%{})

      with_mocks([
        {AccessGroups, [], [
          update: fn(_) -> %AccessGroup{id: access_group.id, name: access_group.name} end,
          get: fn(_) -> %AccessGroup{id: access_group.id, name: access_group.name} end
        ]},
        {Andi.Repo, [], [
          preload: fn(_, _) -> %{datasets: [], users: [], id: access_group.id} end,
          get: fn(Andi.InputSchemas.AccessGroup, _) -> [] end
        ]}
      ]) do
        assert {:ok, view, html} = live(conn, "#{@url_path}/#{access_group.id}")

        assert get_text(html, ".access-groups-sub-table__cell") =~ "No Associated Datasets"
      end
    end

    test "shows an associated dataset", %{conn: conn} do
      %{id: access_group_id, name: access_group_name} = access_group = TDG.create_access_group(%{})
      %{id: dataset_id} = dataset = TDG.create_dataset(%{})

      with_mocks([
        {AccessGroups, [], [
          update: fn(_) -> %AccessGroup{id: access_group_id, name: access_group_name} end,
          get: fn(_) -> %AccessGroup{id: access_group_id, name: access_group_name} end
        ]},
        {Andi.Repo, [], [
          preload: fn(_, _) -> %{datasets: [%{id: dataset_id}], users: [], id: access_group_id} end,
          get: fn(Andi.InputSchemas.AccessGroup, _) -> [] end
        ]},
        {Andi.InputSchemas.Datasets, [], [get: fn(dataset_id) -> dataset end]}
      ]) do
        assert {:ok, view, html} = live(conn, "#{@url_path}/#{access_group_id}")

        assert get_text(html, ".access-groups-sub-table__cell") =~ dataset.business.dataTitle
      end
    end

    test "shows multiple associated datasets", %{conn: conn} do
      %{id: access_group_id, name: access_group_name} = access_group = TDG.create_access_group(%{})
      %{id: dataset_1_id} = dataset_1 = TDG.create_dataset(%{})
      %{id: dataset_2_id} = dataset_2 = TDG.create_dataset(%{})

      with_mocks([
        {AccessGroups, [], [
          update: fn(_) -> %AccessGroup{id: access_group_id, name: access_group_name} end,
          get: fn(_) -> %AccessGroup{id: access_group_id, name: access_group_name} end
        ]},
        {Andi.Repo, [], [
          preload: fn(_, _) -> %{datasets: [%{id: dataset_1_id}, %{id: dataset_2_id}], users: [], id: access_group_id} end,
          get: fn(Andi.InputSchemas.AccessGroup, _) -> [] end
        ]},
        {Andi.InputSchemas.Datasets, [], [
          get: fn
            (^dataset_1_id) -> dataset_1
            (^dataset_2_id) -> dataset_2
          end
        ]}
      ]) do
        assert {:ok, view, html} = live(conn, "#{@url_path}/#{access_group_id}")

        assert get_text(html, ".access-groups-sub-table__data-title-cell") =~ dataset_1.business.dataTitle
        assert get_text(html, ".access-groups-sub-table__data-title-cell") =~ dataset_2.business.dataTitle
      end
    end

    test "shows a remove button for each dataset", %{conn: conn} do
      %{id: access_group_id, name: access_group_name} = access_group = TDG.create_access_group(%{})
      %{id: dataset_1_id} = dataset_1 = TDG.create_dataset(%{})
      %{id: dataset_2_id} = dataset_2 = TDG.create_dataset(%{})

      with_mocks([
        {Andi.Repo, [], [
          preload: fn(_, _) -> %{datasets: [%{id: dataset_1_id}, %{id: dataset_2_id}], users: [], id: access_group_id} end,
          get: fn(Andi.InputSchemas.AccessGroup, _) -> [] end
        ]},
        {Andi.InputSchemas.Datasets, [], [
          get: fn
            (^dataset_1_id) -> dataset_1
            (^dataset_2_id) -> dataset_2
          end
        ]},
        {AccessGroups, [], [
          update: fn(_) -> %AccessGroup{id: access_group_id, name: access_group_name} end,
          get: fn(_) -> %AccessGroup{id: access_group_id, name: access_group_name} end
        ]}
      ]) do
        assert {:ok, view, html} = live(conn, "#{@url_path}/#{access_group_id}")
        text = get_text(html, ".access-groups-sub-table__cell")
        results = Regex.scan(~r/Remove/, text)

        assert length(results) == 2
      end
    end
  end
end
