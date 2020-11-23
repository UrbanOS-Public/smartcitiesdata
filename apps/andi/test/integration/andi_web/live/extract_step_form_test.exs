defmodule AndiWeb.ExtractStepFormTest do
  @moduledoc false

  use ExUnit.Case
  use Andi.DataCase
  use AndiWeb.Test.AuthConnCase.IntegrationCase
  use Checkov

  @moduletag shared_data_connection: true

  import Phoenix.LiveViewTest
  import SmartCity.TestHelper, only: [eventually: 1]
  import FlokiHelpers, only: [find_elements: 2, get_text: 2]

  alias SmartCity.TestDataGenerator, as: TDG
  alias Andi.InputSchemas.Datasets
  alias Andi.InputSchemas.ExtractSteps
  alias Andi.Services.DatasetStore

  @url_path "/datasets/"

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
      default_extract_step,
      date_extract_step
    ]

    smrt_dataset = TDG.create_dataset(%{technical: %{extractSteps: extract_steps}})
    {:ok, andi_dataset} = Datasets.update(smrt_dataset)

    {:ok, view, html} = live(conn, @url_path <> andi_dataset.id)

    [view: view, html: html, andi_dataset: andi_dataset]
  end

  test "given a dataset with many extract steps, all steps are rendered", %{html: html} do
    assert find_elements(html, ".extract-step-container") |> Enum.count() == 2
    refute Enum.empty?(find_elements(html, ".extract-http-step-form"))
    refute Enum.empty?(find_elements(html, ".extract-date-step-form"))
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

  test "when an http extract step is added, its changeset adds a body field", %{conn: conn} do
    smrt_dataset = TDG.create_dataset(%{technical: %{extractSteps: []}})
    {:ok, andi_dataset} = Datasets.update(smrt_dataset)

    {:ok, view, html} = live(conn, @url_path <> andi_dataset.id)

    editor = find_live_child(view, "extract_step_form_editor")
    finalize_editor = find_live_child(view, "finalize_form_editor")

    render_change(editor, "update_new_step_type", %{"value" => "http"})

    render_change(editor, "update_new_step_type", %{"value" => "http"})
    render_click(editor, "add-extract-step")

    render_click(editor, "save")

    andi_dataset = Andi.InputSchemas.Datasets.get(smrt_dataset.id)
    extract_step_id = get_extract_step_id(andi_dataset, 0)
    es_form = element(editor, "#step-#{extract_step_id} form")

    render_change(es_form, %{"form_data" => %{"action" => "GET", "url" => "cam.com", "body" => ""}})

    render_click(editor, "save")
    render_click(finalize_editor, "publish")

    eventually(fn ->
      extract_step = ExtractSteps.all_for_technical(andi_dataset.technical.id) |> List.first()
      assert extract_step != nil
      assert Map.has_key?(extract_step.context, "body")

      {:ok, smrt_dataset} = DatasetStore.get(andi_dataset.id)
      assert nil != smrt_dataset

      smrt_extract_step = get_in(smrt_dataset, [:technical, :extractSteps]) |> List.first()
      assert smrt_extract_step |> Map.get("context") |> Map.get("body") != nil
    end)
  end

  test "given an invalid extract step, the section shows an invalid status", %{andi_dataset: dataset, view: view} do
    extract_step_id = get_extract_step_id(dataset, 0)
    extract_steps_form_view = find_live_child(view, "extract_step_form_editor")
    es_form = element(extract_steps_form_view, "#step-#{extract_step_id} form")

    form_data = %{"type" => "http", "action" => "GET", "url" => ""}
    render_change(es_form, %{"form_data" => form_data})

    render_change(extract_steps_form_view, "save")

    eventually(fn ->
      html = render(extract_steps_form_view)
      assert Enum.empty?(find_elements(html, ".component-number--invalid")) == false
    end)
  end

  test "given an invalid extract date step, the section shows an invalid status", %{andi_dataset: dataset, view: view} do
    extract_step_id = get_extract_step_id(dataset, 1)
    extract_steps_form_view = find_live_child(view, "extract_step_form_editor")
    es_form = element(extract_steps_form_view, "#step-#{extract_step_id} form")

    form_data = %{"destination" => "some_field", "deltaTimeUnit" => "", "deltaTimeValue" => 1, "format" => ""}
    render_change(es_form, %{"form_data" => form_data})

    render_change(extract_steps_form_view, "save")

    eventually(fn ->
      html = render(extract_steps_form_view)
      assert Enum.empty?(find_elements(html, ".component-number--invalid")) == false
    end)
  end

  test "given an previously invalid extract step, and its made valid, the section shows a valid status", %{
    andi_dataset: dataset,
    view: view
  } do
    extract_step_id = get_extract_step_id(dataset, 0)
    extract_steps_form_view = find_live_child(view, "extract_step_form_editor")
    es_form = element(extract_steps_form_view, "#step-#{extract_step_id} form")

    form_data = %{"action" => "GET", "url" => ""}
    render_change(es_form, %{"form_data" => form_data})

    render_change(extract_steps_form_view, "save")

    form_data = %{"action" => "GET", "url" => "bob.com"}
    render_change(es_form, %{"form_data" => form_data})

    eventually(fn ->
      html = render(extract_steps_form_view)
      assert Enum.empty?(find_elements(html, ".component-number--valid")) == false
    end)
  end

  test "pressing the up arrow on an extract step moves it up the list of extract steps", %{view: view, andi_dataset: dataset, html: html} do
    extract_step_id = get_extract_step_id(dataset, 1)
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
    andi_dataset: dataset,
    html: html
  } do
    extract_step_id = get_extract_step_id(dataset, 0)
    extract_steps_form_view = find_live_child(view, "extract_step_form_editor")
    original_extract_ids_from_html = find_elements(html, ".extract-step-container") |> get_extract_step_ids_from_html()
    expected_extract_ids_from_html = Enum.reverse(original_extract_ids_from_html)

    render_change(extract_steps_form_view, "move-extract-step", %{"id" => extract_step_id, "move-index" => "1"})

    eventually(fn ->
      html = render(extract_steps_form_view)
      assert find_elements(html, ".extract-step-container") |> get_extract_step_ids_from_html() == expected_extract_ids_from_html
    end)
  end

  data_test "attempting to move an extract step out of index bounds does nothing", %{view: view, andi_dataset: dataset, html: html} do
    extract_step_id = get_extract_step_id(dataset, original_index)
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

  test "pressing step delete button removes it from ecto", %{view: view, andi_dataset: dataset} do
    extract_step_id = get_extract_step_id(dataset, 0)
    extract_steps_form_view = find_child(view, "extract_step_form_editor")

    html = render_change(extract_steps_form_view, "remove-extract-step", %{"id" => extract_step_id})

    eventually(fn ->
      assert Enum.empty?(find_elements(html, "#step-#{extract_step_id}"))
      assert ExtractSteps.get(extract_step_id) == nil
    end)
  end

  data_test "empty extract steps are invalid", %{conn: conn} do
    smrt_ds = TDG.create_dataset(%{technical: %{extractSteps: extract_steps}})
    {:ok, andi_dataset} = Datasets.update(smrt_ds)

    {:ok, view, html} = live(conn, @url_path <> andi_dataset.id)
    extract_steps_form_view = find_child(view, "extract_step_form_editor")

    assert get_text(html, ".extract-steps__error-message") == "Extract steps cannot be empty"

    html = render_click(extract_steps_form_view, "save")

    eventually(fn ->
      assert not Enum.empty?(find_elements(html, ".component-number-status--invalid"))
    end)

    where(extract_steps: [nil, []])
  end

  test "extract steps without a http step are invalid", %{conn: conn} do
    smrt_ds = TDG.create_dataset(%{technical: %{extractSteps: [%{type: "date", context: %{destination: "blah", format: "{YYYY}"}}]}})
    {:ok, andi_dataset} = Datasets.update(smrt_ds)

    {:ok, view, html} = live(conn, @url_path <> andi_dataset.id)
    extract_steps_form_view = find_child(view, "extract_step_form_editor")

    assert get_text(html, ".extract-steps__error-message") == "Dataset requires at least one HTTP step"

    html = render_click(extract_steps_form_view, "save")

    eventually(fn ->
      assert not Enum.empty?(find_elements(html, ".component-number-status--invalid"))
    end)
  end

  test "validation is updated when steps are added and removed", %{conn: conn} do
    smrt_ds = TDG.create_dataset(%{technical: %{extractSteps: []}})
    {:ok, andi_dataset} = Datasets.update(smrt_ds)

    {:ok, view, html} = live(conn, @url_path <> andi_dataset.id)
    extract_steps_form_view = find_child(view, "extract_step_form_editor")

    html = render_click(extract_steps_form_view, "save")

    refute Enum.empty?(find_elements(html, ".component-number-status--invalid"))

    render_click(extract_steps_form_view, "update_new_step_type", %{"value" => "http"})
    html = render_click(extract_steps_form_view, "add-extract-step")

    assert get_text(html, ".extract-steps__error-message") == ""

    render_click(extract_steps_form_view, "save")
    extract_step_id = ExtractSteps.all_for_technical(andi_dataset.technical.id) |> List.first() |> Map.get(:id)

    form_data = %{"url" => "cam", "action" => "GET"}
    render_change([extract_steps_form_view, "#step-#{extract_step_id}"], "validate", %{"form_data" => form_data})
    html = render(extract_steps_form_view)

    refute Enum.empty?(find_elements(html, ".component-number-status--valid"))

    html = render_click(extract_steps_form_view, "remove-extract-step", %{"id" => extract_step_id})

    refute Enum.empty?(find_elements(html, ".component-number-status--invalid"))
  end

  test "placeholder extract steps are able to be saved and published", %{conn: conn} do
    smrt_ds =
      TDG.create_dataset(%{
        technical: %{
          extractSteps: [
            %{
              type: "s3",
              context: %{
                url: "something.com"
              }
            },
            %{
              type: "http",
              context: %{
                url: "somethingelse.com",
                action: "GET"
              }
            }
          ]
        }
      })

    {:ok, andi_dataset} = Datasets.update(smrt_ds)

    {:ok, view, html} = live(conn, @url_path <> andi_dataset.id)
    extract_steps_form_view = find_child(view, "extract_step_form_editor")
    finalize_editor = find_child(view, "finalize_form_editor")

    html = render_click(extract_steps_form_view, "save")

    refute Enum.empty?(find_elements(html, ".component-number-status--valid"))

    render_click(finalize_editor, "publish")

    eventually(fn ->
      html = render(view)
      refute Enum.empty?(find_elements(html, ".publish-success-modal--visible"))

      {:ok, smrt_dataset} = DatasetStore.get(andi_dataset.id)
      assert nil != smrt_dataset
    end)
  end

  defp get_extract_step_id(dataset, index) do
    dataset
    |> Andi.InputSchemas.StructTools.to_map()
    |> get_in([:technical, :extractSteps])
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
