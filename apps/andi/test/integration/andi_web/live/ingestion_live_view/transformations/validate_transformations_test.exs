defmodule AndiWeb.IngestionLiveView.Transformations.ValidateTransformationsTest do
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

  test "shows invalid status when field is invalid", %{conn: conn, view: view, ingestion: ingestion} do
    expand_transformation_editor(view)
    transformation_id = add_transformation(view)
    data = %{"name" => "", "id" => transformation_id, "type" => "", "sourceField" => ""}
    edit_transformation(view, transformation_id, data)
    minimize_transformation_editor(view)

    eventually(fn ->
      assert element(view, ".component-number--invalid") |> has_element?
      assert element(view, ".component-number-status--invalid") |> has_element?
    end)
  end

  test "shows valid status when all fields are valid", %{conn: conn, view: view, ingestion: ingestion, html: html} do
    expand_transformation_editor(view)
    transformation_id = add_transformation(view)
    data = %{"name" => "test", "id" => transformation_id, "type" => "remove", "sourceField" => "sourcey"}
    edit_transformation(view, transformation_id, data)
    minimize_transformation_editor(view)

    eventually(fn ->
      assert element(view, ".component-number--valid") |> has_element?
      assert element(view, ".component-number-status--valid") |> has_element?
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

  defp minimize_transformation_editor(view) do
    find_live_child(view, "transformations_form_editor")
    |> element("#transformations-form .component-header")
    |> render_click()
  end

  defp expand_transformation_editor(view) do
    find_live_child(view, "transformations_form_editor")
    |> element("#transformations-form .component-header")
    |> render_click()
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
end
