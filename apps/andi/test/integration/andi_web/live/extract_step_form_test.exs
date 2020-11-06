defmodule AndiWeb.ExtractStepFormTest do
  @moduledoc false

  use ExUnit.Case
  use Andi.DataCase
  use AndiWeb.Test.AuthConnCase.IntegrationCase

  @moduletag shared_data_connection: true

  import Phoenix.LiveViewTest
  import SmartCity.TestHelper, only: [eventually: 1]
  import FlokiHelpers, only: [find_elements: 2]

  alias SmartCity.TestDataGenerator, as: TDG
  alias Andi.InputSchemas.Datasets

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
        deltaTimeUnit: "year",
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
    editor = find_child(view, "extract_step_form_editor")

    render_change(editor, "update_new_step_type", %{"value" => "date"})
    render_click(editor, "add-extract-step")

    eventually(fn ->
      html = render(editor)
      assert find_elements(html, ".extract-step-container") |> Enum.count() == 3
      assert Enum.count(find_elements(html, ".extract-date-step-form")) == 2
    end)
  end

  test "given an invalid extract step, the section shows an invalid status", %{andi_dataset: dataset, view: view} do
    extract_step_id = get_extract_step_id(dataset, 0)
    extract_steps_form_view = find_child(view, "extract_step_form_editor")

    form_data = %{"type" => "http", "action" => "GET", "url" => ""}
    render_change([extract_steps_form_view, "#step-#{extract_step_id}"], "validate", %{"form_data" => form_data})

    render_change(extract_steps_form_view, "save")

    eventually(fn ->
      html = render(extract_steps_form_view)
      assert Enum.empty?(find_elements(html, ".component-number--invalid")) == false
    end)
  end

  test "given an invalid extract date step, the section shows an invalid status", %{andi_dataset: dataset, view: view} do
    extract_step_id = get_extract_step_id(dataset, 1)
    extract_steps_form_view = find_child(view, "extract_step_form_editor")

    form_data = %{"destination" => "some_field", "deltaTimeUnit" => "", "deltaTimeValue" => 1, "format" => ""}
    render_change([extract_steps_form_view, "#step-#{extract_step_id}"], "validate", %{"form_data" => form_data})

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
    extract_steps_form_view = find_child(view, "extract_step_form_editor")

    form_data = %{"action" => "GET", "url" => ""}
    render_change([extract_steps_form_view, "#step-#{extract_step_id}"], "validate", %{"form_data" => form_data})

    render_change(extract_steps_form_view, "save")

    form_data = %{"action" => "GET", "url" => "bob.com"}
    render_change([extract_steps_form_view, "#step-#{extract_step_id}"], "validate", %{"form_data" => form_data})

    eventually(fn ->
      html = render(extract_steps_form_view)
      assert Enum.empty?(find_elements(html, ".component-number--valid")) == true
    end)
  end

  defp get_extract_step_id(dataset, index) do
    dataset
    |> Andi.InputSchemas.StructTools.to_map()
    |> get_in([:technical, :extractSteps])
    |> Enum.at(index)
    |> Map.get(:id)
  end
end
