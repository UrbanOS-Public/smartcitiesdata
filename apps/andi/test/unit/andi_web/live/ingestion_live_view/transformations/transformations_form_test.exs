defmodule AndiWeb.IngestionLiveView.Transformations.TransformationFormTest do
  use ExUnit.Case
  import Phoenix.ConnTest
  import Phoenix.LiveViewTest

  alias Andi.InputSchemas.Ingestions.Transformation
  alias AndiWeb.IngestionLiveView.Transformations.TransformationForm

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

    test "can be expanded and collapsed when clicking the header" do
      transformation_changeset = Transformation.changeset_for_draft(%{})
      assert {:ok, view, html} = render_transformation_form(transformation_changeset)
      assert has_element?(view, ".transformation-edit-form--collapsed")

      element(view, ".transformation-header") |> render_click()
      assert has_element?(view, ".transformation-edit-form--expanded")

      element(view, ".transformation-header") |> render_click()
      assert has_element?(view, ".transformation-edit-form--collapsed")
    end

    test "after selecting type with only one field, field appears" do
      transformation_changeset = Transformation.changeset_for_draft(%{})
      assert {:ok, view, html} = render_transformation_form(transformation_changeset)

      select_type("remove", view)

      assert has_element?(view, ".transformation-field")
      assert element(view, ".transformation-field-label", "Field to Remove") |> has_element?()
      assert element(view, "#form_data_sourceField") |> has_element?()
    end
  end

  defp render_transformation_form(transformation_changeset) do
    live_isolated(build_conn(), TransformationForm, session: %{"transformation_changeset" => transformation_changeset})
  end

  defp select_type(type, view) do
    click_value = %{"value" => type}
    element(view, "#form_data_type") |> render_click(click_value)
  end
end
