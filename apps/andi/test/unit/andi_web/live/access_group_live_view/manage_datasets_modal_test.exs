defmodule AndiWeb.AccessGroupLiveView.ManageDatasetsModalTest do
  use AndiWeb.Test.AuthConnCase.UnitCase

  import Mock
  import Phoenix.LiveViewTest
  import FlokiHelpers, only: [get_text: 2]

  alias Andi.Schemas.User
  alias SmartCity.TestDataGenerator, as: TDG
  alias Andi.InputSchemas.AccessGroups
  alias Andi.InputSchemas.AccessGroup
  alias Andi.InputSchemas.Datasets.Dataset

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

  describe "Basic dataset search load" do
    test "shows \"No Matching Datasets\" when there are no rows to show", %{conn: conn} do
      access_group_id = UUID.uuid4()

      with_mocks([
        {Andi.InputSchemas.Datasets, [], [get_all: fn() -> [] end]},
        {AccessGroups, [], [
          update: fn(_) -> %AccessGroup{id: UUID.uuid4(), name: "group"} end,
          get: fn(_) -> %AccessGroup{id: UUID.uuid4(), name: "group"} end
        ]},
        {Andi.Repo, [], [
          get: fn(Andi.InputSchemas.AccessGroup, _) -> [] end,
          preload: fn(_, _) -> %{datasets: [], users: [], id: access_group_id} end
        ]}
      ]) do
        access_group = create_access_group(access_group_id)
        assert {:ok, view, html} = live(conn, "#{@url_path}/#{access_group_id}")

        manage_datasets_button = find_manage_datasets_button(view)
        render_click(manage_datasets_button)

        assert get_text(html, ".search-table__cell") =~ "No Matching Datasets"
      end
    end

    test "represents a dataset when one exists", %{conn: conn} do
      access_group_id = UUID.uuid4()

      with_mocks([
        {AccessGroups, [], [
          update: fn(_) -> %AccessGroup{id: UUID.uuid4(), name: "group"} end,
          get: fn(_) -> %AccessGroup{id: UUID.uuid4(), name: "group"} end
        ]},
        {Andi.Repo, [], [
          all: fn(_) -> [%Dataset{business: %{dataTitle: "Noodles", orgTitle: "Happy", keywords: ["Soup"]}}] end,
          get: fn(Andi.InputSchemas.AccessGroup, _) -> [] end,
          preload: fn(_, _) -> %{datasets: [], users: [], id: access_group_id} end
        ]}
      ]) do
        access_group = create_access_group(access_group_id)
        assert {:ok, view, html} = live(conn, "#{@url_path}/#{access_group_id}")

        manage_datasets_button = find_manage_datasets_button(view)
        render_click(manage_datasets_button)

        html = render_submit(view, "dataset-search", %{"search-value" => "Noodles"})

        assert get_text(html, ".search-table__cell") =~ "Noodles"
        assert get_text(html, ".search-table__cell") =~ "Happy"
        assert get_text(html, ".search-table__cell") =~ "Soup"
      end
    end

    test "represents multiple datasets", %{conn: conn} do
      access_group_id = UUID.uuid4()

      with_mocks([
        {AccessGroups, [], [
          update: fn(_) -> %AccessGroup{id: UUID.uuid4(), name: "group"} end,
          get: fn(_) -> %AccessGroup{id: UUID.uuid4(), name: "group"} end
        ]},
        {Andi.Repo, [], [
          all: fn(_) -> [
            %Dataset{business: %{dataTitle: "Noodles", orgTitle: "Happy", keywords: ["Soup"]}},
            %Dataset{business: %{dataTitle: "Flowers", orgTitle: "Gardener", keywords: ["Pretty"]}}
          ] end,
          get: fn(Andi.InputSchemas.AccessGroup, _) -> [] end,
          preload: fn(_, _) -> %{datasets: [], users: [], id: access_group_id} end
        ]}
      ]) do
        access_group = create_access_group(access_group_id)

        assert {:ok, view, html} = live(conn, "#{@url_path}/#{access_group_id}")

        manage_datasets_button = find_manage_datasets_button(view)
        render_click(manage_datasets_button)

        html = render_submit(view, "dataset-search", %{"search-value" => "Noodles"})

        assert get_text(html, ".search-table__cell") =~ "Noodles"
        assert get_text(html, ".search-table__cell") =~ "Happy"
        assert get_text(html, ".search-table__cell") =~ "Soup"
        assert get_text(html, ".search-table__cell") =~ "Flowers"
        assert get_text(html, ".search-table__cell") =~ "Gardener"
        assert get_text(html, ".search-table__cell") =~ "Pretty"
      end
    end
  end

  defp create_access_group(uuid) do
    access_group = TDG.create_access_group(%{name: "Smrt Access Group", id: uuid})
    AccessGroups.update(access_group)
    access_group
  end

  defp find_manage_datasets_button(view) do
    element(view, ".btn", "Manage Datasets")
  end
end
