defmodule AndiWeb.IngestionLiveView.Transformations.SaveTest do
  use ExUnit.Case
  use Andi.DataCase
  use AndiWeb.Test.AuthConnCase.IntegrationCase
  use Checkov
  use Properties, otp_app: :andi

  @moduletag shared_data_connection: true

  import Phoenix.LiveViewTest
  import SmartCity.TestHelper, only: [eventually: 1]

  alias Andi.InputSchemas.Ingestions

  @url_path "/ingestions/"

  setup %{conn: conn} do
    ingestion = Ingestions.create()

    {:ok, view, html} = navigate_to_edit_page(conn, ingestion)
    %{conn: conn, view: view, html: html, ingestion: ingestion}
  end

  test "can save with no transformations", %{conn: conn, view: view, html: html, ingestion: ingestion} do
    assert count_transformations(html) == 0

    save(view)

    eventually(fn ->
      {:ok, _, refreshed_html} = navigate_to_edit_page(conn, ingestion)
      assert count_transformations(refreshed_html) == 0
    end)
  end

  test "can save blank transformation", %{conn: conn, view: view, html: html, ingestion: ingestion} do
    assert count_transformations(html) == 0

    add_transformation(view)
    save(view)

    eventually(fn ->
      {:ok, _, refreshed_html} = navigate_to_edit_page(conn, ingestion)
      assert count_transformations(refreshed_html) == 1
    end)
  end

  test "can save transformation name", %{conn: conn, view: view, ingestion: ingestion} do
    transformation_id = add_transformation(view)
    data = %{"name" => "something", "id" => transformation_id, "type" => ""}
    edit_transformation(view, transformation_id, data)
    save(view)

    eventually(fn ->
      {:ok, _, refreshed_html} = navigate_to_edit_page(conn, ingestion)
      assert count_transformations(refreshed_html) == 1
      assert transformation_has_name?(refreshed_html, "something")
    end)
  end

  test "can save transformation type", %{conn: conn, view: view, ingestion: ingestion} do
    transformation_id = add_transformation(view)
    data = %{"name" => "", "id" => transformation_id, "type" => "remove"}
    edit_transformation(view, transformation_id, data)
    save(view)

    eventually(fn ->
      {:ok, _, refreshed_html} = navigate_to_edit_page(conn, ingestion)
      assert count_transformations(refreshed_html) == 1
      assert transformation_has_type?(refreshed_html, "remove")
    end)
  end

  test "can save transformation fields", %{conn: conn, view: view, ingestion: ingestion} do
    transformation_id = add_transformation(view)
    data = %{"name" => "", "id" => transformation_id, "type" => "remove", "sourceField" => "sourcey"}
    edit_transformation(view, transformation_id, data)
    save(view)

    eventually(fn ->
      {:ok, _, refreshed_html} = navigate_to_edit_page(conn, ingestion)
      assert count_transformations(refreshed_html) == 1
      assert transformation_has_parameter?(refreshed_html, "sourceField", "sourcey")
    end)
  end

  test "can change transformation fields after save", %{conn: conn, view: view, ingestion: ingestion} do
    transformation_id = add_transformation(view)

    data = %{"name" => "", "id" => transformation_id, "type" => "remove", "sourceField" => "sourcey"}
    edit_transformation(view, transformation_id, data)
    save(view)

    eventually(fn ->
      {:ok, _, refreshed_html} = navigate_to_edit_page(conn, ingestion)
      assert transformation_has_parameter?(refreshed_html, "sourceField", "sourcey")
    end)

    data = %{"name" => "", "id" => transformation_id, "type" => "remove", "sourceField" => "changed my mind"}
    edit_transformation(view, transformation_id, data)
    save(view)

    eventually(fn ->
      {:ok, _, refreshed_html} = navigate_to_edit_page(conn, ingestion)
      assert transformation_has_parameter?(refreshed_html, "sourceField", "changed my mind")
    end)
  end

  defp navigate_to_edit_page(conn, ingestion) do
    live(conn, @url_path <> ingestion.id)
  end

  defp save(view) do
    element(view, ".btn--save", "Save Draft Ingestion")
    |> render_click()
  end

  defp add_transformation(view) do
    find_live_child(view, "transformations_form_editor")
    |> element("#add-transformation")
    |> render_click()
    |> find_transformation_id()
  end

  defp find_transformation_id(html) do
    {:ok, document} = Floki.parse_document(html)
    Floki.find(document, "#transformation-forms")
    |> Floki.find("[data-phx-view=\"IngestionLiveView.Transformations.TransformationForm\"]")
    |> Floki.attribute("id")
    |> List.first()
    |> String.replace_prefix("transform-", "")
  end

  defp edit_transformation(view, transformation_id, data) do
    data = %{"form_data" => data}
    find_live_child(view, "transformations_form_editor")
    |> find_live_child("transform-#{transformation_id}")
    |> element(".transformation-item")
    |> render_change(data)
  end

  defp count_transformations(html) do
    {:ok, document} = Floki.parse_document(html)

    Floki.find(document, ".transformation-item")
    |> length()
  end

  defp transformation_has_name?(html, expected_name) do
    {:ok, document} = Floki.parse_document(html)
    actual_name = Floki.find(document, ".transformation-name")
    |> Floki.attribute("value")
    |> List.first()
    actual_name == expected_name
  end

  defp transformation_has_type?(html, expected_type) do
    {:ok, document} = Floki.parse_document(html)
    actual_type = Floki.find(document, ".transformation-type")
    |> Floki.find("option:checked")
    |> Floki.attribute("value")
    |> List.first()
    actual_type == expected_type
  end

  defp transformation_has_parameter?(html, parameter, expected_value) do
    {:ok, document} = Floki.parse_document(html)
    actual_value = Floki.find(document, "#form_data_#{parameter}")
    |> Floki.attribute("value")
    |> List.first()
    actual_value == expected_value
  end
end
