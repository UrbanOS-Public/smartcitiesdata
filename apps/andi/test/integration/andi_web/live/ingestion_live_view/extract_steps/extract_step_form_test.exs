defmodule AndiWeb.IngestionLiveView.ExtractSteps.ExtractStepFormTest do
  @moduledoc false

  use ExUnit.Case
  use Andi.DataCase
  use AndiWeb.Test.AuthConnCase.IntegrationCase
  use Checkov
  use Properties, otp_app: :andi

  @moduletag shared_data_connection: true

  import Phoenix.LiveViewTest
  import SmartCity.TestHelper, only: [eventually: 1]
  import FlokiHelpers, only: [find_elements: 2, get_text: 2]

  alias Andi.InputSchemas.Ingestions
  alias Andi.InputSchemas.ExtractSteps

  @url_path "/ingestions/"

  getter(:hosted_bucket, generic: true)

  setup %{conn: conn} do
    default_extract_step = %{
      type: "http",
      id: UUID.uuid4(),
      context: %{
        action: "GET",
        url: "example.com"
      }
    }

    date_extract_step = %{
      type: "date",
      id: UUID.uuid4(),
      context: %{
        destination: "bob_field",
        deltaTimeUnit: "years",
        deltaTimeValue: 5,
        format: "{ISO:Extended}"
      }
    }

    extract_steps = [
      date_extract_step,
      default_extract_step
    ]

    andi_ingestion = create_ingestion_with_dataset(extract_steps)

    {:ok, view, html} = live(conn, @url_path <> andi_ingestion.id)

    %{view: view, html: html, andi_ingestion: andi_ingestion}
  end

  test "given an ingestion with many extract steps, all steps are rendered", %{html: html} do
    assert find_elements(html, ".extract-step-container") |> Enum.count() == 2
    assert not Enum.empty?(find_elements(html, ".extract-http-step-form"))
    assert not Enum.empty?(find_elements(html, ".extract-date-step-form"))
  end

  test "when the add step button is pressed, a new step is rendered", %{view: view} do
    editor = find_live_child(view, "extract_step_form_editor")

    render_change(editor, "update_new_step_type", %{"value" => "date"})
    render_click(editor, "add-extract-step")

    eventually(fn ->
      html = render(editor)
      assert find_elements(html, ".extract-step-container") |> Enum.count() == 3
      assert Enum.count(find_elements(html, ".extract-date-step-form")) == 2
    end)
  end

  # flag: stuck on this with nicole for the moment
  test "when an http extract step is added, its changeset adds a body field", %{conn: conn} do
    extract_steps = []
    andi_ingestion = create_ingestion_with_dataset(extract_steps)

    {:ok, view, _} = live(conn, @url_path <> andi_ingestion.id)

    editor = find_live_child(view, "extract_step_form_editor")

    render_change(editor, "update_new_step_type", %{"value" => "http"})
    render_click(editor, "add-extract-step")

    render_click(view, "save")

    updated_andi_ingestion = Andi.InputSchemas.Ingestions.get(andi_ingestion.id)
    extract_step_id = get_extract_step_id(updated_andi_ingestion, 0)
    es_form = element(editor, "#step-#{extract_step_id} form")

    render_change(es_form, %{"form_data" => %{"action" => "GET", "url" => "cam.com", "body" => "test"}})

    render_click(view, "save")

    eventually(fn ->
      extract_step = ExtractSteps.all_for_ingestion(andi_ingestion.id) |> List.first()
      assert extract_step != nil
      assert Map.has_key?(extract_step.context, "body")
    end)
  end

  test "given an invalid extract http step, the section shows an invalid status", %{andi_ingestion: ingestion, view: view} do
    extract_step_id = get_extract_step_id(ingestion, 1)
    extract_steps_form_view = find_live_child(view, "extract_step_form_editor")
    es_form = element(extract_steps_form_view, "#step-#{extract_step_id} form")

    form_data = %{"type" => "http", "action" => "GET", "url" => ""}
    render_change(es_form, %{"form_data" => form_data})

    render_change(extract_steps_form_view, "save")

    eventually(fn ->
      html = render(extract_steps_form_view)
      assert not Enum.empty?(find_elements(html, ".component-number--invalid"))
    end)
  end

  test "given an invalid extract date step, the section shows an invalid status", %{andi_ingestion: ingestion, view: view} do
    extract_step_id = get_extract_step_id(ingestion, 0)
    extract_steps_form_view = find_live_child(view, "extract_step_form_editor")
    es_form = element(extract_steps_form_view, "#step-#{extract_step_id} form")

    form_data = %{"destination" => "some_field", "deltaTimeUnit" => "", "deltaTimeValue" => 1, "format" => ""}
    render_change(es_form, %{"form_data" => form_data})

    render_change(extract_steps_form_view, "save")

    eventually(fn ->
      html = render(extract_steps_form_view)
      assert not Enum.empty?(find_elements(html, ".component-number--invalid"))
    end)
  end

  test "given a previously invalid extract step, and it's made valid, the section shows a valid status", %{
    andi_ingestion: ingestion,
    view: view
  } do
    extract_step_id = get_extract_step_id(ingestion, 0)
    extract_steps_form_view = find_live_child(view, "extract_step_form_editor")
    es_form = element(extract_steps_form_view, "#step-#{extract_step_id} form")

    form_data = %{"action" => "GET", "url" => ""}
    render_change(es_form, %{"form_data" => form_data})

    render_change(extract_steps_form_view, "save")

    form_data = %{"action" => "GET", "url" => "bob.com"}
    render_change(es_form, %{"form_data" => form_data})

    eventually(fn ->
      html = render(extract_steps_form_view)
      assert not Enum.empty?(find_elements(html, ".component-number--valid"))
    end)
  end

  test "pressing the up arrow on an extract step moves it up the list of extract steps", %{
    view: view,
    andi_ingestion: ingestion,
    html: html
  } do
    extract_step_id = get_extract_step_id(ingestion, 1)
    extract_steps_form_view = find_live_child(view, "extract_step_form_editor")
    original_extract_ids_from_html = find_elements(html, ".extract-step-container") |> get_extract_step_ids_from_html()
    expected_extract_ids_from_html = Enum.reverse(original_extract_ids_from_html)

    render_change(extract_steps_form_view, "move-extract-step", %{"id" => extract_step_id, "move-index" => "-1"})

    eventually(fn ->
      html = render(extract_steps_form_view)
      assert find_elements(html, ".extract-step-container") |> get_extract_step_ids_from_html() == expected_extract_ids_from_html
    end)
  end

  test "pressing the down arrow on an extract step moves it down the list of extract steps", %{
    view: view,
    andi_ingestion: ingestion,
    html: html
  } do
    extract_step_id = get_extract_step_id(ingestion, 0)
    extract_steps_form_view = find_live_child(view, "extract_step_form_editor")
    original_extract_ids_from_html = find_elements(html, ".extract-step-container") |> get_extract_step_ids_from_html()
    expected_extract_ids_from_html = Enum.reverse(original_extract_ids_from_html)

    render_change(extract_steps_form_view, "move-extract-step", %{"id" => extract_step_id, "move-index" => "1"})

    eventually(fn ->
      html = render(extract_steps_form_view)
      assert find_elements(html, ".extract-step-container") |> get_extract_step_ids_from_html() == expected_extract_ids_from_html
    end)
  end

  data_test "attempting to move an extract step out of index bounds does nothing", %{view: view, andi_ingestion: ingestion, html: html} do
    extract_step_id = get_extract_step_id(ingestion, original_index)
    extract_steps_form_view = find_live_child(view, "extract_step_form_editor")
    original_extract_ids_from_html = find_elements(html, ".extract-step-container") |> get_extract_step_ids_from_html()

    render_change(extract_steps_form_view, "move-extract-step", %{"id" => extract_step_id, "move-index" => move_index_string})

    eventually(fn ->
      html = render(extract_steps_form_view)
      assert find_elements(html, ".extract-step-container") |> get_extract_step_ids_from_html() == original_extract_ids_from_html
    end)

    where([
      [:original_index, :move_index_string],
      [0, "-1"],
      [1, "1"]
    ])
  end

  test "pressing step delete button removes it from ecto", %{view: view, andi_ingestion: ingestion} do
    extract_step_id = get_extract_step_id(ingestion, 0)
    extract_steps_form_view = find_live_child(view, "extract_step_form_editor")

    html = render_change(extract_steps_form_view, "remove-extract-step", %{"id" => extract_step_id})

    eventually(fn ->
      assert Enum.empty?(find_elements(html, "#step-#{extract_step_id}"))
      assert ExtractSteps.get(extract_step_id) == nil
    end)
  end

  data_test "empty extract steps are invalid", %{conn: conn} do
    andi_ingestion = create_ingestion_with_dataset(extract_steps)

    {:ok, view, html} = live(conn, @url_path <> andi_ingestion.id)
    extract_steps_form_view = find_live_child(view, "extract_step_form_editor")

    assert get_text(html, ".extract-steps__error-message") == "Extract steps cannot be empty"

    html = render_click(extract_steps_form_view, "save")

    eventually(fn ->
      assert not Enum.empty?(find_elements(html, ".component-number-status--invalid"))
    end)

    where(extract_steps: [nil, []])
  end

  test "extract steps without a trailing http or s3 step are invalid", %{conn: conn} do
    andi_ingestion = create_ingestion_with_dataset([%{type: "date", context: %{destination: "blah", format: "{YYYY}"}}])

    {:ok, view, html} = live(conn, @url_path <> andi_ingestion.id)
    extract_steps_form_view = find_live_child(view, "extract_step_form_editor")

    assert get_text(html, ".extract-steps__error-message") == "Extract steps must end with a HTTP or S3 step"

    html = render_click(extract_steps_form_view, "save")

    eventually(fn ->
      assert not Enum.empty?(find_elements(html, ".component-number-status--invalid"))
    end)
  end

  test "validation is updated when steps are added and removed", %{conn: conn} do
    extract_steps = []
    andi_ingestion = create_ingestion_with_dataset(extract_steps)

    {:ok, view, _} = live(conn, @url_path <> andi_ingestion.id)
    extract_steps_form_view = find_live_child(view, "extract_step_form_editor")

    html = render_click(extract_steps_form_view, "save")

    assert not Enum.empty?(find_elements(html, ".component-number-status--invalid"))

    render_click(extract_steps_form_view, "update_new_step_type", %{"value" => "http"})
    html = render_click(extract_steps_form_view, "add-extract-step")

    assert get_text(html, ".extract-steps__error-message") == ""

    render_click(extract_steps_form_view, "save")
    extract_step_id = ExtractSteps.all_for_ingestion(andi_ingestion.id) |> List.first() |> Map.get(:id)

    form_data = %{"url" => "cam", "action" => "GET"}
    es_form = element(extract_steps_form_view, "#step-#{extract_step_id} form")

    render_change(es_form, %{"form_data" => form_data})
    html = render(extract_steps_form_view)

    assert not Enum.empty?(find_elements(html, ".component-number-status--valid"))

    html = render_click(extract_steps_form_view, "remove-extract-step", %{"id" => extract_step_id})

    assert not Enum.empty?(find_elements(html, ".component-number-status--invalid"))
  end

  test "clicking the edit button reveals the step contents", %{conn: conn, andi_ingestion: andi_ingestion} do
    {:ok, view, _} = live(conn, @url_path <> andi_ingestion.id)
    extract_steps_form_view = find_live_child(view, "extract_step_form_editor")
    html = render(extract_steps_form_view)

    assert not Enum.empty?(find_elements(html, ".component-edit-section--collapsed"))

    html = render_click(extract_steps_form_view, "toggle-component-visibility")

    assert not Enum.empty?(find_elements(html, ".component-edit-section--expanded"))

    html = render_click(extract_steps_form_view, "toggle-component-visibility")

    assert not Enum.empty?(find_elements(html, ".component-edit-section--collapsed"))
  end

  defp create_ingestion_with_dataset(extract_steps) do
    ingestion = Ingestions.create()
    {:ok, andi_ingestion} = Ingestions.update(Map.merge(ingestion, %{extractSteps: extract_steps}))

    andi_ingestion
  end

  defp get_extract_step_id(ingestion, index) do
    ingestion
    |> Andi.InputSchemas.StructTools.to_map()
    |> Map.get(:extractSteps)
    |> Enum.at(index)
    |> Map.get(:id)
  end

  defp get_extract_step_ids_from_html(html_list) do
    Enum.map(html_list, fn {_, attributes, _} ->
      extract_step_html_id =
        attributes
        |> Map.new()
        |> Map.get("id")

      "step-" <> extract_step_id = extract_step_html_id
      extract_step_id
    end)
  end
end
