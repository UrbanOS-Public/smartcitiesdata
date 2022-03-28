defmodule AndiWeb.AccessGroupLiveView.EditAccessGroupLiveViewTest do
  use ExUnit.Case
  use Andi.DataCase
  use AndiWeb.Test.AuthConnCase.IntegrationCase

  @moduletag shared_data_connection: true

  import Placebo
  import Phoenix.LiveViewTest
  import SmartCity.Event
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
  alias Andi.InputSchemas.Datasets.Dataset
  alias SmartCity.DatasetAccessGroupRelation

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

  describe "can select a dataset" do
    test "a dataset can be selected", %{curator_conn: conn} do
      {:ok, dataset_a} = TDG.create_dataset(business: %{orgTitle: "org_a"}) |> Datasets.update()

      access_group = create_access_group()
      assert {:ok, view, html} = live(conn, "#{@url_path}/#{access_group.id}")

      add_dataset_button = element(view, ".btn", "+ Add Dataset")
      render_click(add_dataset_button)

      html = render_submit(view, :search, %{"search-value" => dataset_a.business.orgTitle})

      select_dataset = element(view, ".modal-action-text", "Select")

      html = render_click(select_dataset)

      assert get_text(html, ".search-table") =~ "Remove"
    end

    test "a selected dataset persists when the search input changes", %{curator_conn: conn} do
      {:ok, dataset_a} = TDG.create_dataset(business: %{orgTitle: "org_a"}) |> Datasets.update()

      access_group = create_access_group()
      assert {:ok, view, html} = live(conn, "#{@url_path}/#{access_group.id}")

      add_dataset_button = element(view, ".btn", "+ Add Dataset")
      render_click(add_dataset_button)

      html = render_submit(view, :search, %{"search-value" => dataset_a.business.orgTitle})
      select_dataset = element(view, ".modal-action-text", "Select")
      html = render_click(select_dataset)

      assert get_text(html, ".selected-dataset-text") =~ dataset_a.business.dataTitle

      html = render_submit(view, :search, %{"search-value" => "some new value"})

      assert get_text(html, ".selected-dataset-text") =~ dataset_a.business.dataTitle
    end

    test "a dataset can be removed", %{curator_conn: conn} do
      {:ok, dataset_a} = TDG.create_dataset(business: %{orgTitle: "org_a"}) |> Datasets.update()

      access_group = create_access_group()
      assert {:ok, view, html} = live(conn, "#{@url_path}/#{access_group.id}")

      add_dataset_button = element(view, ".btn", "+ Add Dataset")
      render_click(add_dataset_button)

      html = render_submit(view, :search, %{"search-value" => dataset_a.business.orgTitle})

      select_dataset = element(view, ".modal-action-text", "Select")
      html = render_click(select_dataset)
      assert get_text(html, ".search-table") =~ "Remove"

      remove_dataset = element(view, ".search-table__cell", "Remove")
      html = render_click(remove_dataset)
      refute get_text(html, ".search-table") =~ "Remove"
    end

    test "a selected dataset appears in the selected dataset list", %{curator_conn: conn} do
      {:ok, dataset_a} = TDG.create_dataset(business: %{orgTitle: "org_a"}) |> Datasets.update()

      access_group = create_access_group()
      assert {:ok, view, html} = live(conn, "#{@url_path}/#{access_group.id}")

      add_dataset_button = element(view, ".btn", "+ Add Dataset")
      render_click(add_dataset_button)

      html = render_submit(view, :search, %{"search-value" => dataset_a.business.orgTitle})

      select_dataset = element(view, ".modal-action-text", "Select")

      html = render_click(select_dataset)

      assert get_text(html, ".selected-datasets-from-search") =~ dataset_a.business.dataTitle
    end

    test "a dataset can be unselected by clicking close", %{curator_conn: conn} do
      {:ok, dataset_a} = TDG.create_dataset(business: %{orgTitle: "org_a"}) |> Datasets.update()

      access_group = create_access_group()
      assert {:ok, view, html} = live(conn, "#{@url_path}/#{access_group.id}")

      add_dataset_button = element(view, ".btn", "+ Add Dataset")
      render_click(add_dataset_button)

      html = render_submit(view, :search, %{"search-value" => dataset_a.business.orgTitle})

      select_dataset = element(view, ".modal-action-text", "Select")
      html = render_click(select_dataset)
      assert get_text(html, ".search-table") =~ "Remove"
      assert get_text(html, ".selected-dataset-text") =~ dataset_a.business.dataTitle

      deselect_dataset = element(view, ".remove-selected-dataset")
      html = render_click(deselect_dataset)

      refute get_text(html, ".search-table") =~ "Remove"
      refute get_text(html, ".selected-dataset-from-search") =~ dataset_a.business.dataTitle
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

    test "filters on keywords", %{curator_conn: conn} do
      {:ok, dataset_a} = TDG.create_dataset(business: %{keywords: ["fun", "times"]}) |> Datasets.update()
      {:ok, dataset_b} = TDG.create_dataset(business: %{keywords: ["sad", "times"]}) |> Datasets.update()

      access_group = create_access_group()
      assert {:ok, view, html} = live(conn, "#{@url_path}/#{access_group.id}")

      add_dataset_button = element(view, ".btn", "+ Add Dataset")
      render_click(add_dataset_button)

      html = render_submit(view, :search, %{"search-value" => "fun"})

      assert get_text(html, ".search-table") =~ "fun"
      refute get_text(html, ".search-table") =~ "sad"
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

  describe "save a dataset search" do
    test "closes the search modal when save is clicked", %{curator_conn: conn} do
      access_group = create_access_group()
      assert {:ok, view, html} = live(conn, "#{@url_path}/#{access_group.id}")

      # add a new dataset to the access group
      add_dataset_button = element(view, ".btn", "+ Add Dataset")
      render_click(add_dataset_button)

      # save the datasets to the access group
      save_button = element(view, ".save-search", "Save")
      render_click(save_button)

      # verify that the search modal is closed
      refute Enum.empty?(find_elements(html, ".add-dataset-modal--hidden"))
    end

    test "saves the results of the search to the dataset table", %{curator_conn: conn} do
      {:ok, dataset_a} = TDG.create_dataset(business: %{orgTitle: "org_a"}) |> Datasets.update()

      access_group = create_access_group()
      assert {:ok, view, html} = live(conn, "#{@url_path}/#{access_group.id}")

      # add a new dataset to the access group
      add_dataset_button = element(view, ".btn", "+ Add Dataset")
      render_click(add_dataset_button)

      # search for the dataset by name and select it
      html = render_submit(view, :search, %{"search-value" => dataset_a.business.orgTitle})
      select_dataset = element(view, ".modal-action-text", "Select")
      html = render_click(select_dataset)
      assert get_text(html, ".search-table") =~ dataset_a.business.orgTitle

      # save the search
      save_button = element(view, ".save-search", "Save")
      html = render_click(save_button)

      # verfy that the selected datasets appear in the datasets table
      assert get_text(html, ".access-groups-dataset-table") =~ dataset_a.business.orgTitle
      assert get_text(html, ".access-groups-dataset-table") =~ dataset_a.business.dataTitle
    end
  end

  describe "emits a dataset_access_group_associate event" do
    test "when the access group is saved, the association is updated", %{curator_conn: conn} do
      {:ok, dataset_a} = TDG.create_dataset(business: %{orgTitle: "org_a"}) |> Datasets.update()
      dataset_id = dataset_a.id

      access_group = create_access_group()
      assert {:ok, view, html} = live(conn, "#{@url_path}/#{access_group.id}")

      # add a new dataset to the access group
      add_dataset_button = element(view, ".btn", "+ Add Dataset")
      render_click(add_dataset_button)

      # search for the dataset by name and select it
      html = render_submit(view, :search, %{"search-value" => dataset_a.business.orgTitle})
      select_dataset = element(view, ".modal-action-text", "Select")
      html = render_click(select_dataset)
      assert get_text(html, ".search-table") =~ dataset_a.business.orgTitle

      # save the search
      save_button = element(view, ".save-search", "Save")
      html = render_click(save_button)

      # verfy that the selected datasets appear in the datasets table
      assert get_text(html, ".access-groups-dataset-table") =~ dataset_a.business.orgTitle
      assert get_text(html, ".access-groups-dataset-table") =~ dataset_a.business.dataTitle

      # save the changes to the access group
      save_button = element(view, ".save-edit", "Save")
      html = render_click(save_button)

      eventually(fn ->
        access_group = AccessGroups.get(access_group.id) |> Andi.Repo.preload(:datasets)
        assert [%Dataset{id: ^dataset_id}] = access_group.datasets
      end)
    end
  end

  test "removes a dataset when remove action is clicked", %{curator_conn: conn} do
    access_group = create_access_group()
    {:ok, dataset} = TDG.create_dataset(business: %{orgTitle: "remove_org"}) |> Datasets.update()
    {:ok, relation} = DatasetAccessGroupRelation.new(%{dataset_id: dataset.id, access_group_id: access_group.id})
    Brook.Event.send(@instance_name, dataset_access_group_associate(), :testing, relation)
    dataset_id = dataset.id
    eventually(fn ->
      access_group = AccessGroups.get(access_group.id) |> Andi.Repo.preload(:datasets)
      assert [%Dataset{id: dataset_id}] = access_group.datasets
    end)
    assert {:ok, view, html} = live(conn, "#{@url_path}/#{access_group.id}")

    remove_action = element(view, ".modal-action-text", "Remove")
    html = render_click(remove_action)

    refute get_text(html, ".access-groups-dataset-table") =~ dataset.business.dataTitle
  end

  test "dissociates dataset after removing from current datasets", %{curator_conn: conn} do
    access_group = create_access_group()
    {:ok, dataset} = TDG.create_dataset(business: %{orgTitle: "dissociate_org"}) |> Datasets.update()
    {:ok, relation} = DatasetAccessGroupRelation.new(%{dataset_id: dataset.id, access_group_id: access_group.id})
    Brook.Event.send(@instance_name, dataset_access_group_associate(), :testing, relation)
    dataset_id = dataset.id
    eventually(fn ->
      access_group = AccessGroups.get(access_group.id) |> Andi.Repo.preload(:datasets)
      assert [%Dataset{id: dataset_id}] = access_group.datasets
    end)
    assert {:ok, view, html} = live(conn, "#{@url_path}/#{access_group.id}")

    remove_action = element(view, ".modal-action-text", "Remove")
    html = render_click(remove_action)

    refute get_text(html, ".access-groups-dataset-table") =~ dataset.business.dataTitle

    # save the changes to the access group
    save_button = element(view, ".save-edit", "Save")
    html = render_click(save_button)

    eventually(fn ->
      access_group = AccessGroups.get(access_group.id) |> Andi.Repo.preload(:datasets)
      assert [] = access_group.datasets
    end)
  end

  test "keeps the dataset if user removes and re-selects", %{curator_conn: conn} do
    access_group = create_access_group()
    {:ok, dataset} = TDG.create_dataset(business: %{orgTitle: "mistake_org"}) |> Datasets.update()
    {:ok, relation} = DatasetAccessGroupRelation.new(%{dataset_id: dataset.id, access_group_id: access_group.id})
    Brook.Event.send(@instance_name, dataset_access_group_associate(), :testing, relation)
    dataset_id = dataset.id
    eventually(fn ->
      access_group = AccessGroups.get(access_group.id) |> Andi.Repo.preload(:datasets)
      assert [%Dataset{id: dataset_id}] = access_group.datasets
    end)
    assert {:ok, view, html} = live(conn, "#{@url_path}/#{access_group.id}")
    remove_action = element(view, ".modal-action-text", "Remove")
    html = render_click(remove_action)

    refute get_text(html, ".access-groups-dataset-table") =~ dataset.business.dataTitle

    add_dataset_button = element(view, ".btn", "+ Add Dataset")
    render_click(add_dataset_button)

    # search for the dataset by org and select it
    html = render_submit(view, :search, %{"search-value" => dataset.business.orgTitle})
    select_dataset = element(view, ".modal-action-text", "Select")
    html = render_click(select_dataset)
    assert get_text(html, ".search-table") =~ dataset.business.orgTitle

    # save the search
    save_button = element(view, ".save-search", "Save")
    html = render_click(save_button)

    # verfy that the selected dataset appear in the datasets table
    assert get_text(html, ".access-groups-dataset-table") =~ dataset.business.orgTitle
    assert get_text(html, ".access-groups-dataset-table") =~ dataset.business.dataTitle

    # save the changes to the access group
    save_button = element(view, ".save-edit", "Save")
    html = render_click(save_button)

    eventually(fn ->
      access_group = AccessGroups.get(access_group.id) |> Andi.Repo.preload(:datasets)
      assert [%Dataset{id: ^dataset_id}] = access_group.datasets
    end)
  end

  test "clicking remove does not open the modal" do
  end

  test "clicking remove for a dataset which is associated and selected removes that dataset" do

  end

  defp create_access_group() do
    uuid = UUID.uuid4()
    access_group = TDG.create_access_group(%{name: "Smrt Access Group", id: uuid})
    AccessGroups.update(access_group)
    access_group
  end
end
