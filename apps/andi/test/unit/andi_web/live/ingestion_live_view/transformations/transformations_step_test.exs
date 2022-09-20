defmodule AndiWeb.IngestionLiveView.Transformations.TransformationsStepTest do
  use ExUnit.Case
  use Placebo

  import Phoenix.ConnTest
  import Phoenix.LiveViewTest

  import FlokiHelpers, only: [find_elements: 2]

  alias Andi.InputSchemas.Ingestions
  alias Andi.InputSchemas.Ingestions.Transformations
  alias Andi.InputSchemas.Ingestions.Transformation
  alias AndiWeb.IngestionLiveView.FormUpdate
  alias AndiWeb.IngestionLiveView.Transformations.TransformationsStep
  alias Andi.InputSchemas.Datasets

  alias SmartCity.TestDataGenerator, as: TDG

  @endpoint AndiWeb.Endpoint

  setup do
    ingestion = TDG.create_ingestion(%{name: "Original"})
    allow Ingestions.get(ingestion.id), return: ingestion
    allow Ingestions.update(ingestion, %{name: "Updated"}), return: {:ok, ingestion}
    allow Transformations.create(), return: create_transformation_changeset()
    allow Transformations.get(any()), return: %{}
    allow Transformations.update(any(), any()), return: %{}
    allow Datasets.get(any()), return: %{business: %{dataTitle: "Dataset Name"}}
    allow Andi.Repo.insert_or_update(any()), return: {:ok, %{}}
    allow FormUpdate.send_value(any(), any()), return: {:ok}

    %{ingestion: ingestion}
  end

  describe "Transformations form" do
    test "can be expanded and collapsed", %{ingestion: ingestion} do
      assert {:ok, view, html} = live_isolated(build_conn(), TransformationsStep, session: %{"ingestion" => ingestion, "order" => "3"})

      click_form_header(view)

      assert element(view, ".component-edit-section--expanded") |> has_element?
      assert element(view, ".component-number--expanded") |> has_element?
      assert element(view, ".component-number-status--expanded") |> has_element?
      refute element(view, ".component-edit-section--collapsed") |> has_element?

      click_form_header(view)

      assert element(view, ".component-edit-section--collapsed") |> has_element?
      assert element(view, ".component-number--valid") |> has_element?
      assert element(view, ".component-number-status--valid") |> has_element?
      refute element(view, ".component-edit-section--expanded") |> has_element?
    end

    test "add transformation creates a new transformation", %{ingestion: ingestion} do
      assert {:ok, view, _html} = live_isolated(build_conn(), TransformationsStep, session: %{"ingestion" => ingestion, "order" => "3"})

      refute element(view, ".transformation-header") |> has_element?

      allow Transformations.create(), return: create_transformation_changeset()
      click_add_transformation(view)

      allow Transformations.create(), return: create_transformation_changeset()
      assert element(view, ".transformation-header") |> has_element?

      html = click_add_transformation(view)

      assert Enum.count(find_elements(html, ".transformation-header")) == 2
    end

    test "add transformation displays transformation header by default", %{ingestion: ingestion} do
      assert {:ok, view, html} = live_isolated(build_conn(), TransformationsStep, session: %{"ingestion" => ingestion, "order" => "3"})

      refute element(view, ".transformation-header") |> has_element?

      html = click_add_transformation(view)

      assert FlokiHelpers.get_text(html, ".transformation-header") =~ "New Transformation"
    end

    test "transformation header displays transformation name" do
      transformation_name = "This is the name that should appear"

      ingestion =
        TDG.create_ingestion(%{
          name: "Original",
          transformations: [
            %{
              type: "concatenation",
              name: transformation_name,
              parameters: %{
                "sourceFields" => ["other", "name"],
                "separator" => ".",
                "targetField" => "name"
              }
            }
          ]
        })

      assert {:ok, view, html} = live_isolated(build_conn(), TransformationsStep, session: %{"ingestion" => ingestion, "order" => "3"})

      assert element(view, ".transformation-header") |> has_element?
      assert FlokiHelpers.get_text(html, ".transformation-header") =~ transformation_name
    end
  end

  defp click_form_header(view) do
    element(view, ".component-header") |> render_click()
  end

  defp click_add_transformation(view) do
    element(view, "#add-transformation") |> render_click()
  end

  defp create_transformation_changeset() do
    Ecto.Changeset.change(%Transformation{}, %{id: UUID.uuid4()})
  end
end
