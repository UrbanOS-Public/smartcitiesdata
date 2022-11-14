defmodule AndiWeb.IngestionLiveView.Transformations.DeleteButtonTest do
  use ExUnit.Case
  use Andi.DataCase
  use AndiWeb.Test.AuthConnCase.IntegrationCase
  use Checkov
  use Properties, otp_app: :andi

  @moduletag shared_data_connection: true

  import Phoenix.LiveViewTest
  import SmartCity.TestHelper, only: [eventually: 1]

  alias Andi.InputSchemas.Ingestions
  alias Andi.InputSchemas.Ingestions.Transformations
  alias Andi.InputSchemas.Ingestions.Transformation

  @url_path "/ingestions/"

  setup %{conn: conn} do
    ingestion = Ingestions.create()
    transform1 = create_transformation_with_name("Alpha", ingestion)
    transform2 = create_transformation_with_name("Beta", ingestion)
    transform3 = create_transformation_with_name("Gamma", ingestion)
    transformations = [transform1, transform2, transform3]

    ingestion
    |> Map.merge(%{transformations: transformations})
    |> Ingestions.update()

    {:ok, view, html} = navigate_to_edit_page(conn, ingestion)
    %{conn: conn, view: view, html: html, ingestion: ingestion}
  end

  test "has a delete button for each transformation", %{html: html} do
    {:ok, document} = Floki.parse_document(html)
    assert Floki.find(document, ".delete-transformation-button") |> Enum.count() == 3
  end

  test "clicking delete removes the transformation from view", %{view: view, html: html, ingestion: ingestion} do
    assert ["Alpha", "Beta", "Gamma"] == find_ordered_names(html)

    get_second_transformation(ingestion.id)
    |> delete_transformation(view)

    assert ["Alpha", "Gamma"] == render(view) |> find_ordered_names()
  end

  test "cancelling after deleting does not save changes", %{conn: conn, view: view, html: html, ingestion: ingestion} do
    assert ["Alpha", "Beta", "Gamma"] == find_ordered_names(html)

    get_second_transformation(ingestion.id)
    |> delete_transformation(view)

    assert ["Alpha", "Gamma"] == render(view) |> find_ordered_names()

    cancel(view)
    confirm_cancel(view)

    {:ok, _, refreshed_html} = navigate_to_edit_page(conn, ingestion)

    assert ["Alpha", "Beta", "Gamma"] == find_ordered_names(refreshed_html)
  end

  test "saving ingestion after deleting discards deleted transformations", %{conn: conn, view: view, html: html, ingestion: ingestion} do
    assert ["Alpha", "Beta", "Gamma"] == find_ordered_names(html)

    get_second_transformation(ingestion.id)
    |> delete_transformation(view)

    assert ["Alpha", "Gamma"] == render(view) |> find_ordered_names()

    save(view)

    eventually(fn ->
      {:ok, _, refreshed_html} = navigate_to_edit_page(conn, ingestion)
      assert ["Alpha", "Gamma"] == find_ordered_names(refreshed_html)
    end)
  end

  test "cancelling with unsaved deletions prompts confirmation", %{view: view, html: html, ingestion: ingestion} do
    assert ["Alpha", "Beta", "Gamma"] == find_ordered_names(html)

    get_second_transformation(ingestion.id)
    |> delete_transformation(view)

    assert ["Alpha", "Gamma"] == render(view) |> find_ordered_names()

    cancel(view)

    assert element(view, ".unsaved-changes-modal--visible")
           |> has_element?()
  end

  defp navigate_to_edit_page(conn, ingestion) do
    live(conn, @url_path <> ingestion.id)
  end

  defp create_transformation_with_name(name, ingestion) do
    {:ok, transformation} =
      %Transformation{
        name: name,
        ingestion_id: ingestion.id,
        id: UUID.uuid4()
      }
      |> Transformations.update()

    transformation
  end

  defp get_second_transformation(ingestion_id) do
    [_ | [second_transformation | _]] = Transformations.all_for_ingestion(ingestion_id)
    second_transformation
  end

  defp find_ordered_names(html) do
    {:ok, document} = Floki.parse_document(html)

    document
    |> Floki.find(".transformation-name")
    |> Floki.attribute("value")
  end

  defp delete_transformation(transformation, view) do
    find_live_child(view, "transformations_form_editor")
    |> element(".delete-#{transformation.id}")
    |> render_click()
  end

  defp cancel(view) do
    element(view, ".btn--cancel", "Discard Changes")
    |> render_click()
  end

  defp confirm_cancel(view) do
    element(view, ".continue-cancel-button")
    |> render_click()
  end

  defp save(view) do
    element(view, ".btn--save", "Save Draft Ingestion")
    |> render_click()
  end
end
