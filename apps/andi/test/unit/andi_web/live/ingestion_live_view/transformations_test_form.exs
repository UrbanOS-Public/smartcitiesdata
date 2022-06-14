defmodule AndiWeb.Unit.IngestionLiveView.MetadataFormTest do
  use ExUnit.Case
  use Placebo

  import Phoenix.ConnTest
  import Phoenix.LiveViewTest

  alias Andi.InputSchemas.Ingestions
  alias AndiWeb.IngestionLiveView.TransformationsForm
  alias Andi.InputSchemas.Datasets

  alias SmartCity.TestDataGenerator, as: TDG

  @endpoint AndiWeb.Endpoint

  describe "Transformations form" do
    test "can be expanded and collapsed" do
      ingestion = TDG.create_ingestion(%{name: "Original"})
      allow Ingestions.get(ingestion.id), return: ingestion
      allow Ingestions.update(ingestion, %{name: "Updated"}), return: {:ok, ingestion}
      allow Datasets.get(any()), return: %{business: %{dataTitle: "Dataset Name"}}

      assert {:ok, view, html} = live_isolated(build_conn(), TransformationsForm, session: %{"ingestion" => ingestion, "order" => "3"})

      click_form_header(view)

      assert element(view, ".component-edit-section--expanded") |> has_element?
      refute element(view, ".component-edit-section--collapsed") |> has_element?

      click_form_header(view)

      assert element(view, ".component-edit-section--collapsed") |> has_element?
      refute element(view, ".component-edit-section--expanded") |> has_element?
    end
  end

  defp click_form_header(view) do
    element(view, ".component-header") |> render_click()
  end
end
