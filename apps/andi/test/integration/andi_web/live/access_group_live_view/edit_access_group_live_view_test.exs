defmodule AndiWeb.AccessGroupLiveView.EditAccessGroupLiveViewTest do
  use ExUnit.Case
  use Andi.DataCase
  use AndiWeb.Test.AuthConnCase.IntegrationCase

  @moduletag shared_data_connection: true

  import Placebo
  import Phoenix.LiveViewTest
  import SmartCity.TestHelper, only: [eventually: 1, eventually: 3]

  import FlokiHelpers,
    only: [
      find_elements: 2,
      get_texts: 2,
      get_text: 2,
      get_attributes: 3
    ]

  alias SmartCity.TestDataGenerator, as: TDG

  alias Andi.InputSchemas.AccessGroup
  alias Andi.InputSchemas.AccessGroups
  alias Andi.InputSchemas.Datasets

  @instance_name Andi.instance_name()

  @url_path "/access-groups"

  describe "curator users access" do
    test "the access group name field is alterable", %{curator_conn: conn} do
      uuid = UUID.uuid4()
      access_group = TDG.create_access_group(%{name: "old-group-name", id: uuid})
      AccessGroups.update(access_group)
      assert {:ok, view, _html} = live(conn, "#{@url_path}/#{uuid}")

      new_access_group_name = "new-group-name"
      form_data = %{"name" => new_access_group_name, "id" => uuid}

      render_change(view, "form_change", %{"form_data" => form_data, "_target" => ["form_data", "name"]})

      save_btn = element(view, ".save-edit", "Save")
      render_click(save_btn)

      eventually(fn ->
        group = AccessGroups.get(uuid)
        assert group != nil
        assert group.name == new_access_group_name
      end)
    end

    test "the access group name is loaded into the name field upon load", %{curator_conn: conn} do
      access_group_name = "cool-group-name"
      uuid = UUID.uuid4()
      access_group = TDG.create_access_group(%{name: access_group_name, id: uuid})
      AccessGroups.update(access_group)

      assert {:ok, view, html} = live(conn, "#{@url_path}/#{uuid}")

      assert [access_group_name] = get_attributes(html, "#form_data_name", "value")
    end

    test "the cancel button redirects users back to the main access groups page", %{curator_conn: conn} do
      uuid = UUID.uuid4()
      access_group = TDG.create_access_group(%{name: "Smrt Access Group", id: uuid})
      AccessGroups.update(access_group)
      assert {:ok, view, html} = live(conn, "#{@url_path}/#{uuid}")

      cancel_button = element(view, ".cancel-edit", "Cancel")

      render_click(cancel_button)
      assert_redirected(view, @url_path)
    end
  end

  describe "add dataset button" do
    test "exists", %{curator_conn: conn} do
      access_group = create_access_group()
      assert {:ok, view, html} = live(conn, "#{@url_path}/#{access_group.id}")

      add_dataset_button = element(view, ".btn", "+ Add Dataset")

      assert has_element?(add_dataset_button)
    end

    test "opens modal on click", %{curator_conn: conn} do
      access_group = create_access_group()
      assert {:ok, view, html} = live(conn, "#{@url_path}/#{access_group.id}")

      add_dataset_button = element(view, ".btn", "+ Add Dataset")

      render_click(add_dataset_button)

      add_dataset_modal = element(view, ".add-dataset-modal")

      assert has_element?(add_dataset_modal)
    end

    test "closes modal on click", %{curator_conn: conn} do
      access_group = create_access_group()
      assert {:ok, view, html} = live(conn, "#{@url_path}/#{access_group.id}")

      add_dataset_button = element(view, ".btn", "+ Add Dataset")

      render_click(add_dataset_button)

      cancel_button = element(view, ".cancel-search", "Cancel")

      render_click(cancel_button)

      refute Enum.empty?(find_elements(html, ".add-dataset-modal--hidden"))
    end
  end

  describe "search" do
    test "filters on orgTitle", %{curator_conn: conn} do
      {:ok, dataset_a} = TDG.create_dataset(business: %{orgTitle: "org_a"}) |> Datasets.update()
      {:ok, dataset_b} = TDG.create_dataset(business: %{orgTitle: "org_b"}) |> Datasets.update()

      access_group = create_access_group()
      assert {:ok, view, html} = live(conn, "#{@url_path}/#{access_group.id}")

      add_dataset_button = element(view, ".btn", "+ Add Dataset")
      render_click(add_dataset_button)

      html = render_submit(view, :search, %{"search-value" => dataset_a.business.orgTitle})

      assert get_text(html, ".search-table") =~ dataset_a.business.orgTitle
      refute get_text(html, ".search-table") =~ dataset_b.business.orgTitle
    end

    test "filters on dataTitle", %{curator_conn: conn} do
      {:ok, dataset_a} = TDG.create_dataset(business: %{dataTitle: "data_a"}) |> Datasets.update()
      {:ok, dataset_b} = TDG.create_dataset(business: %{dataTitle: "data_b"}) |> Datasets.update()

      access_group = create_access_group()
      assert {:ok, view, html} = live(conn, "#{@url_path}/#{access_group.id}")

      add_dataset_button = element(view, ".btn", "+ Add Dataset")
      render_click(add_dataset_button)

      html = render_submit(view, :search, %{"search-value" => dataset_a.business.dataTitle})

      assert get_text(html, ".search-table") =~ dataset_a.business.dataTitle
      refute get_text(html, ".search-table") =~ dataset_b.business.dataTitle
    end

    test "shows No Datasets if no results returned", %{curator_conn: conn} do
      {:ok, _dataset_a} = TDG.create_dataset(business: %{dataTitle: "data_a"}) |> Datasets.update()
      {:ok, _dataset_b} = TDG.create_dataset(business: %{dataTitle: "data_b"}) |> Datasets.update()

      access_group = create_access_group()
      assert {:ok, view, html} = live(conn, "#{@url_path}/#{access_group.id}")

      add_dataset_button = element(view, ".btn", "+ Add Dataset")
      render_click(add_dataset_button)

      html = render_change(view, :search, %{"search-value" => "__NOT_RESULTS_SHOULD RETURN__"})

      assert get_text(html, ".search-table") =~ "No Matching Datasets"
    end
  end

  defp create_access_group() do
    uuid = UUID.uuid4()
    access_group = TDG.create_access_group(%{name: "Smrt Access Group", id: uuid})
    AccessGroups.update(access_group)
    access_group
  end
end
