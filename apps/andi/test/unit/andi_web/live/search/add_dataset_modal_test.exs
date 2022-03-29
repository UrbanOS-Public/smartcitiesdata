defmodule AndiWeb.Search.AddDatasetModalTest do
  use AndiWeb.Test.AuthConnCase.UnitCase
  use Placebo
  alias Andi.Schemas.User

  import Phoenix.LiveViewTest
  import FlokiHelpers, only: [get_text: 2]

  alias SmartCity.TestDataGenerator, as: TDG
  alias Andi.InputSchemas.AccessGroups
  alias Andi.InputSchemas.AccessGroup
  alias Andi.InputSchemas.Datasets.Dataset

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

  describe "Basic dataset search load" do
    test "shows \"No Matching Datasets\" when there are no rows to show", %{conn: conn} do
      allow(Andi.InputSchemas.Datasets.get_all(), return: [])
      allow(AccessGroups.update(any()), return: %AccessGroup{id: UUID.uuid4(), name: "group"})
      allow(AccessGroups.get(any()), return: %AccessGroup{id: UUID.uuid4(), name: "group"})
      allow(Andi.Repo.get(Andi.InputSchemas.AccessGroup, any()), return: [])
      allow(Andi.Repo.preload(any(), any()), return: %{datasets: []})

      access_group = create_access_group()
      assert {:ok, view, html} = live(conn, "#{@url_path}/#{access_group.id}")

      add_dataset_button = element(view, ".btn", "Manage Dataset")

      render_click(add_dataset_button)

      assert get_text(html, ".search-table__cell") =~ "No Matching Datasets"
    end

    test "represents a dataset when one exists", %{conn: conn} do
      allow(Andi.Repo.all(any()), return: [%Dataset{business: %{dataTitle: "Noodles", orgTitle: "Happy", keywords: ["Soup"]}}])
      allow(AccessGroups.update(any()), return: %AccessGroup{id: UUID.uuid4(), name: "group"})
      allow(AccessGroups.get(any()), return: %AccessGroup{id: UUID.uuid4(), name: "group"})
      allow(Andi.Repo.get(Andi.InputSchemas.AccessGroup, any()), return: [])
      allow(Andi.Repo.preload(any(), any()), return: %{datasets: []})
      access_group = create_access_group()
      assert {:ok, view, html} = live(conn, "#{@url_path}/#{access_group.id}")

      add_dataset_button = element(view, ".btn", "Manage Dataset")

      render_click(add_dataset_button)

      html = render_submit(view, :search, %{"search-value" => "Noodles"})

      assert get_text(html, ".search-table__cell") =~ "Noodles"
      assert get_text(html, ".search-table__cell") =~ "Happy"
      assert get_text(html, ".search-table__cell") =~ "Soup"
    end

    test "represents multiple datasets", %{conn: conn} do
      allow(Andi.Repo.all(any()),
        return: [
          %Dataset{business: %{dataTitle: "Noodles", orgTitle: "Happy", keywords: ["Soup"]}},
          %Dataset{business: %{dataTitle: "Flowers", orgTitle: "Gardener", keywords: ["Pretty"]}}
        ]
      )

      allow(AccessGroups.update(any()), return: %AccessGroup{id: UUID.uuid4(), name: "group"})
      allow(AccessGroups.get(any()), return: %AccessGroup{id: UUID.uuid4(), name: "group"})
      allow(Andi.Repo.get(Andi.InputSchemas.AccessGroup, any()), return: [])
      allow(Andi.Repo.preload(any(), any()), return: %{datasets: []})
      access_group = create_access_group()
      assert {:ok, view, html} = live(conn, "#{@url_path}/#{access_group.id}")

      add_dataset_button = element(view, ".btn", "Manage Dataset")

      render_click(add_dataset_button)

      html = render_submit(view, :search, %{"search-value" => "Noodles"})

      assert get_text(html, ".search-table__cell") =~ "Noodles"
      assert get_text(html, ".search-table__cell") =~ "Happy"
      assert get_text(html, ".search-table__cell") =~ "Soup"
      assert get_text(html, ".search-table__cell") =~ "Flowers"
      assert get_text(html, ".search-table__cell") =~ "Gardener"
      assert get_text(html, ".search-table__cell") =~ "Pretty"
    end
  end

  defp create_access_group() do
    uuid = UUID.uuid4()
    access_group = TDG.create_access_group(%{name: "Smrt Access Group", id: uuid})
    AccessGroups.update(access_group)
    access_group
  end
end
