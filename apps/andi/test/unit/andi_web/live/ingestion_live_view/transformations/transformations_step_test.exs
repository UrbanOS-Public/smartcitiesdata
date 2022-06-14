defmodule AndiWeb.IngestionLiveView.Transformations.TransformationsStepTest do
  use ExUnit.Case
  use Placebo

  import Phoenix.ConnTest
  import Phoenix.LiveViewTest

  import FlokiHelpers, only: [find_elements: 2]

  alias Andi.InputSchemas.Ingestions
  alias AndiWeb.IngestionLiveView.Transformations.TransformationsStep
  alias Andi.InputSchemas.Datasets

  alias SmartCity.TestDataGenerator, as: TDG

  @endpoint AndiWeb.Endpoint

  setup do
    ingestion = TDG.create_ingestion(%{name: "Original"})
    allow Ingestions.get(ingestion.id), return: ingestion
    allow Ingestions.update(ingestion, %{name: "Updated"}), return: {:ok, ingestion}
    allow Datasets.get(any()), return: %{business: %{dataTitle: "Dataset Name"}}

    %{ingestion: ingestion}
  end

  describe "Transformations form" do
    test "can be expanded and collapsed", %{ingestion: ingestion} do
      assert {:ok, view, html} = live_isolated(build_conn(), TransformationsForm, session: %{"ingestion" => ingestion, "order" => "3"})

      click_form_header(view)

      assert element(view, ".component-edit-section--expanded") |> has_element?
      refute element(view, ".component-edit-section--collapsed") |> has_element?

      click_form_header(view)

      assert element(view, ".component-edit-section--collapsed") |> has_element?
      refute element(view, ".component-edit-section--expanded") |> has_element?
    end

    test "add transformation creates a new transformation", %{ingestion: ingestion} do
      assert {:ok, view, _html} = live_isolated(build_conn(), TransformationsForm, session: %{"ingestion" => ingestion, "order" => "3"})

      refute element(view, ".transformation") |> has_element?

      click_add_transformation(view)

      assert element(view, ".transformation") |> has_element?

      html = click_add_transformation(view)

      assert Enum.count(find_elements(html, ".transformation")) == 2
    end
  end

  defp click_form_header(view) do
    element(view, ".component-header") |> render_click()
  end

  defp click_add_transformation(view) do
    element(view, "#add-transformation") |> render_click()
  end
end
