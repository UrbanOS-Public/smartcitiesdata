defmodule AndiWeb.IngestionLiveView.Transformations.MoveButtonsTest do
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
    transform1 = create_transformation_with_name("Black", ingestion)
    transform2 = create_transformation_with_name("Blue", ingestion)
    transform3 = create_transformation_with_name("Green", ingestion)
    transformations = [transform1, transform2, transform3]

    ingestion
    |> Map.merge(%{transformations: transformations})
    |> Ingestions.update()

    {:ok, view, html} = navigate_to_edit_page(conn, ingestion)
    %{conn: conn, view: view, html: html, ingestion: ingestion}
  end

  test "has move up and down buttons for each transformation", %{html: html} do
    {:ok, document} = Floki.parse_document(html)
    assert Floki.find(document, ".move-up") |> Enum.count() == 3
    assert Floki.find(document, ".move-down") |> Enum.count() == 3
  end

  test "clicking move up slides that transformation up one row", %{view: view, html: html, ingestion: ingestion} do
    assert ["Black", "Blue", "Green"] == find_ordered_names(html)

    get_second_transformation(ingestion.id)
    |> move_up(view)

    assert ["Blue", "Black", "Green"] == render(view) |> find_ordered_names()
  end

  test "clicking move down slides that transformation down one row", %{view: view, html: html, ingestion: ingestion} do
    assert ["Black", "Blue", "Green"] == find_ordered_names(html)

    get_second_transformation(ingestion.id)
    |> move_down(view)

    assert ["Black", "Green", "Blue"] == render(view) |> find_ordered_names()
  end

  test "cancelling after moving does not save changes", %{conn: conn, view: view, html: html, ingestion: ingestion} do
    assert ["Black", "Blue", "Green"] == find_ordered_names(html)

    get_second_transformation(ingestion.id)
    |> move_down(view)

    assert ["Black", "Green", "Blue"] == render(view) |> find_ordered_names()

    cancel(view)
    confirm_cancel(view)

    {:ok, _, refreshed_html} = navigate_to_edit_page(conn, ingestion)

    assert ["Black", "Blue", "Green"] == find_ordered_names(refreshed_html)
  end

  test "saving ingestion after moving preserves order", %{conn: conn, view: view, html: html, ingestion: ingestion} do
    assert ["Black", "Blue", "Green"] == find_ordered_names(html)

    get_second_transformation(ingestion.id)
    |> move_up(view)

    assert ["Blue", "Black", "Green"] == render(view) |> find_ordered_names()

    save(view)

    eventually fn ->
      {:ok, _, refreshed_html} = navigate_to_edit_page(conn, ingestion)
      assert ["Blue", "Black", "Green"] == find_ordered_names(refreshed_html)
    end
  end

  test "cancelling with unsaved move changes prompts confirmation", %{conn: conn, view: view, html: html, ingestion: ingestion} do
    assert ["Black", "Blue", "Green"] == find_ordered_names(html)

    get_second_transformation(ingestion.id)
    |> move_up(view)

    assert ["Blue", "Black", "Green"] == render(view) |> find_ordered_names()

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

  defp move_up(transformation, view) do
    find_live_child(view, "transformations_form_editor")
    |> find_live_child("transform-#{transformation.id}")
    |> element(".move-up-#{transformation.id}")
    |> render_click()
  end

  defp move_down(transformation, view) do
    find_live_child(view, "transformations_form_editor")
    |> find_live_child("transform-#{transformation.id}")
    |> element(".move-down-#{transformation.id}")
    |> render_click()
  end

  defp cancel(view) do
    element(view, ".btn--cancel")
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
