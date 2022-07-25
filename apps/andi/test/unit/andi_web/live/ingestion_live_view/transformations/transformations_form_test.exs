defmodule AndiWeb.IngestionLiveView.Transformations.TransformationFormTest do
  use ExUnit.Case
  import Phoenix.ConnTest
  import Phoenix.LiveViewTest

  alias Andi.InputSchemas.Ingestions.Transformation
  alias AndiWeb.IngestionLiveView.Transformations.TransformationForm
  alias AndiWeb.Views.Options

  @endpoint AndiWeb.Endpoint

  describe "Transformations form" do
    test "Shows errors for missing name field" do
      transformation_changeset = Transformation.changeset_for_draft(%{})
      assert {:ok, view, html} = render_transformation_form(transformation_changeset)

      form_update = %{
        "name" => "   "
      }

      element(view, ".transformation-item") |> render_change(form_update)

      assert element(view, "#name-error-msg") |> has_element?
    end

    test "Header defaults to Transformation when transformation name is cleared from form" do
      transformation_changeset = Transformation.changeset_for_draft(%{})
      assert {:ok, view, html} = render_transformation_form(transformation_changeset)

      form_update = %{
        "name" => ""
      }

      element(view, ".transformation-item") |> render_change(form_update)

      assert FlokiHelpers.get_text(html, ".transformation-header") =~ "New Transformation"
    end

    test "Shows errors for missing type field" do
      transformation_changeset = Transformation.changeset_for_draft(%{})
      assert {:ok, view, html} = render_transformation_form(transformation_changeset)

      form_update = %{
        "type" => ""
      }

      element(view, ".transformation-item") |> render_change(form_update)

      assert element(view, "#type-error-msg") |> has_element?
    end

    test "Shows transformation type dropdown with correct options" do
      transformation_changeset = Transformation.changeset_for_draft(%{})
      assert {:ok, view, html} = render_transformation_form(transformation_changeset)

      options = FlokiHelpers.get_all_select_options(html, ".transformation-form__type")

      assert options == [
               {"", ""},
               {"Concatenation", "concatenation"},
               {"Conversion", "conversion"},
               {"DateTime", "datetime"},
               {"Regex Extract", "regex_extract"},
               {"Regex Replace", "regex_replace"},
               {"Remove", "remove"}
             ]
    end
  end

  defp render_transformation_form(transformation_changeset) do
    live_isolated(build_conn(), TransformationForm, session: %{"transformation_changeset" => transformation_changeset})
  end
end
