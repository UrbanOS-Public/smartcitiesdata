defmodule AndiWeb.ExtractStepFormTest do
  @moduledoc false

  use ExUnit.Case
  use Andi.DataCase
  use AndiWeb.Test.AuthConnCase.IntegrationCase

  @moduletag shared_data_connection: true

  import Phoenix.LiveViewTest

  import FlokiHelpers,
    only: [
      get_attributes: 3,
      get_value: 2,
      get_values: 2,
      get_select: 2,
      get_select_first_option: 2,
      get_text: 2,
      find_elements: 2
    ]

  alias SmartCity.TestDataGenerator, as: TDG
  alias Andi.InputSchemas.Datasets

  @url_path "/datasets/"

  setup %{conn: conn} do
    smrt_dataset = TDG.create_dataset(%{technical: %{extractSteps: [%{type: "http"}, %{type: "http"}]}})
    {:ok, andi_dataset} = Datasets.update(smrt_dataset)

    {:ok, view, html} = live(conn, @url_path <> andi_dataset.id)

    [view: view, html: html, andi_dataset: andi_dataset]
  end

  test "given a dataset with many extract steps, all steps are rendered", %{html: html} do
    assert find_elements(html, ".extract-step-container") |> Enum.count() == 2
  end

  test "when the add step button is pressed, a new step is rendered", %{view: view} do
    editor = find_child(view, "extract_step_form_editor")

    html = render_click(editor, :add_extract_step)

    assert find_elements(html, ".extract-step-container") |> Enum.count() == 3
  end
end
