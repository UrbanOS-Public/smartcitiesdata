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

      field_id = build_field_id("sourceField")
      assert has_element?(view, ".transformation-field")
      assert element(view, "label[for=#{field_id}]", "Field to Remove") |> has_element?()
      assert element(view, "##{field_id}") |> has_element?()
    end

    test "if type is selected show fields on load" do
      transformation_changeset = Transformation.changeset_for_draft(%{type: "remove"})

      assert {:ok, view, html} = render_transformation_form(transformation_changeset)

      field_id = build_field_id("sourceField")
      assert has_element?(view, ".transformation-field")
      assert element(view, "label[for=#{field_id}]", "Field to Remove") |> has_element?()
      assert element(view, "##{field_id}") |> has_element?()
    end

    test "after selecting regex replace, regex extract fields appear" do
      transformation_changeset = Transformation.changeset_for_draft(%{})
      assert {:ok, view, html} = render_transformation_form(transformation_changeset)

      select_type("regex_replace", view)

      source_field_id = build_field_id("sourceField")
      replacement_field_id = build_field_id("replacement")
      regex_field_id = build_field_id("regex")

      assert has_element?(view, ".transformation-field")
      assert element(view, "label[for=#{source_field_id}]", "Source Field") |> has_element?()
      assert element(view, "label[for=#{regex_field_id}]", "Regex") |> has_element?()
      assert element(view, "label[for=#{replacement_field_id}]", "Replacement") |> has_element?()
      assert element(view, "##{source_field_id}") |> has_element?()
      assert element(view, "##{replacement_field_id}") |> has_element?()
      assert element(view, "##{regex_field_id}") |> has_element?()
    end

    test "if regex replace is selected show fields on load" do
      transformation_changeset = Transformation.changeset_for_draft(%{type: "regex_replace"})

      assert {:ok, view, html} = render_transformation_form(transformation_changeset)

      source_field_id = build_field_id("sourceField")
      replacement_field_id = build_field_id("replacement")
      regex_field_id = build_field_id("regex")

      assert has_element?(view, ".transformation-field")
      assert element(view, "label[for=#{source_field_id}]", "Source Field") |> has_element?()
      assert element(view, "label[for=#{regex_field_id}]", "Regex") |> has_element?()
      assert element(view, "label[for=#{replacement_field_id}]", "Replacement") |> has_element?()
      assert element(view, "##{source_field_id}") |> has_element?()
      assert element(view, "##{replacement_field_id}") |> has_element?()
      assert element(view, "##{regex_field_id}") |> has_element?()
    end

    test "after selecting regex extract, regex extract fields appear" do
      transformation_changeset = Transformation.changeset_for_draft(%{})
      assert {:ok, view, html} = render_transformation_form(transformation_changeset)

      select_type("regex_extract", view)

      source_field_id = build_field_id("sourceField")
      target_field_id = build_field_id("targetField")
      regex_field_id = build_field_id("regex")

      assert has_element?(view, ".transformation-field")
      assert element(view, "label[for=#{source_field_id}]", "Source Field") |> has_element?()
      assert element(view, "label[for=#{regex_field_id}]", "Regex") |> has_element?()
      assert element(view, "label[for=#{target_field_id}]", "Target Field") |> has_element?()
      assert element(view, "##{source_field_id}") |> has_element?()
      assert element(view, "##{target_field_id}") |> has_element?()
      assert element(view, "##{regex_field_id}") |> has_element?()
    end

    test "if regex extract is selected show fields on load" do
      transformation_changeset = Transformation.changeset_for_draft(%{type: "regex_extract"})

      assert {:ok, view, html} = render_transformation_form(transformation_changeset)

      source_field_id = build_field_id("sourceField")
      target_field_id = build_field_id("targetField")
      regex_field_id = build_field_id("regex")

      assert has_element?(view, ".transformation-field")
      assert element(view, "label[for=#{source_field_id}]", "Source Field") |> has_element?()
      assert element(view, "label[for=#{regex_field_id}]", "Regex") |> has_element?()
      assert element(view, "label[for=#{target_field_id}]", "Target Field") |> has_element?()
      assert element(view, "##{source_field_id}") |> has_element?()
      assert element(view, "##{target_field_id}") |> has_element?()
      assert element(view, "##{regex_field_id}") |> has_element?()
    end

    test "after selecting DateTime, date time fields appear" do
      transformation_changeset = Transformation.changeset_for_draft(%{})
      assert {:ok, view, html} = render_transformation_form(transformation_changeset)

      select_type("datetime", view)

      source_field_id = build_field_id("sourceField")
      source_format_id = build_field_id("sourceFormat")
      target_field_id = build_field_id("targetField")
      target_format_id = build_field_id("targetFormat")

      assert has_element?(view, ".transformation-field")
      assert element(view, "label[for=#{source_field_id}]", "Source Field") |> has_element?()
      assert element(view, "label[for=#{source_format_id}]", "Source Field Format") |> has_element?()
      assert element(view, "label[for=#{target_field_id}]", "Target Field") |> has_element?()
      assert element(view, "label[for=#{target_format_id}]", "Target Field Format") |> has_element?()
      assert element(view, "##{source_field_id}") |> has_element?()
      assert element(view, "##{source_format_id}") |> has_element?()
      assert element(view, "##{target_field_id}") |> has_element?()
      assert element(view, "##{target_format_id}") |> has_element?()
    end

    test "if DateTime is selected show fields on load" do
      transformation_changeset = Transformation.changeset_for_draft(%{type: "datetime"})

      assert {:ok, view, html} = render_transformation_form(transformation_changeset)

      source_field_id = build_field_id("sourceField")
      source_format_id = build_field_id("sourceFormat")
      target_field_id = build_field_id("targetField")
      target_format_id = build_field_id("targetFormat")

      assert has_element?(view, ".transformation-field")
      assert element(view, "label[for=#{source_field_id}]", "Source Field") |> has_element?()
      assert element(view, "label[for=#{source_format_id}]", "Source Field Format") |> has_element?()
      assert element(view, "label[for=#{target_field_id}]", "Target Field") |> has_element?()
      assert element(view, "label[for=#{target_format_id}]", "Target Field Format") |> has_element?()
      assert element(view, "##{source_field_id}") |> has_element?()
      assert element(view, "##{source_format_id}") |> has_element?()
      assert element(view, "##{target_field_id}") |> has_element?()
      assert element(view, "##{target_format_id}") |> has_element?()
    end

    test "after selecting conversion transformation, conversion fields appear" do
      transformation_changeset = Transformation.changeset_for_draft(%{})
      assert {:ok, view, html} = render_transformation_form(transformation_changeset)

      select_type("conversion", view)

      target_field_id = build_field_id("field")
      source_field_type = build_field_id("sourceType")
      target_field_type = build_field_id("targetType")

      assert has_element?(view, ".transformation-field")
      assert element(view, "label[for=#{target_field_id}]", "Field to Convert") |> has_element?()
      assert element(view, "label[for=#{source_field_type}]", "Source Data Type") |> has_element?()
      assert element(view, "label[for=#{target_field_type}]", "Target Data Type") |> has_element?()
      assert element(view, "##{target_field_id}") |> has_element?()
      assert element(view, "##{source_field_type}") |> has_element?()
      assert element(view, "##{target_field_type}") |> has_element?()
    end

    test "if conversion transformation is selected show fields on load" do
      transformation_changeset = Transformation.changeset_for_draft(%{type: "conversion"})

      assert {:ok, view, html} = render_transformation_form(transformation_changeset)

      target_field_id = build_field_id("field")
      source_field_type = build_field_id("sourceType")
      target_field_type = build_field_id("targetType")

      assert has_element?(view, ".transformation-field")
      assert element(view, "label[for=#{target_field_id}]", "Field to Convert") |> has_element?()
      assert element(view, "label[for=#{source_field_type}]", "Source Data Type") |> has_element?()
      assert element(view, "label[for=#{target_field_type}]", "Target Data Type") |> has_element?()
      assert element(view, "##{target_field_id}") |> has_element?()
      assert element(view, "##{source_field_type}") |> has_element?()
      assert element(view, "##{target_field_type}") |> has_element?()
    end

    test "after selecting concatenation transformation, conversion fields appear" do
      transformation_changeset = Transformation.changeset_for_draft(%{})
      assert {:ok, view, html} = render_transformation_form(transformation_changeset)

      select_type("concatenation", view)

      source_fields_id = build_field_id("sourceFields")
      target_field_id = build_field_id("targetField")
      separator_field_id = build_field_id("separator")

      assert has_element?(view, ".transformation-field")
      assert element(view, "label[for=#{source_fields_id}]", "Source Fields") |> has_element?()
      assert element(view, "label[for=#{target_field_id}]", "Target Field") |> has_element?()
      assert element(view, "label[for=#{separator_field_id}]", "Separator") |> has_element?()
      assert element(view, "##{source_fields_id}") |> has_element?()
      assert element(view, "##{target_field_id}") |> has_element?()
      assert element(view, "##{separator_field_id}") |> has_element?()
    end

    test "if concatenation transformation is selected show fields on load" do
      transformation_changeset = Transformation.changeset_for_draft(%{type: "concatenation"})

      assert {:ok, view, html} = render_transformation_form(transformation_changeset)

      source_fields_id = build_field_id("sourceFields")
      target_field_id = build_field_id("targetField")
      separator_field_id = build_field_id("separator")

      assert has_element?(view, ".transformation-field")
      assert element(view, "label[for=#{source_fields_id}]", "Source Fields") |> has_element?()
      assert element(view, "label[for=#{target_field_id}]", "Target Field") |> has_element?()
      assert element(view, "label[for=#{separator_field_id}]", "Separator") |> has_element?()
      assert element(view, "##{source_fields_id}") |> has_element?()
      assert element(view, "##{target_field_id}") |> has_element?()
      assert element(view, "##{separator_field_id}") |> has_element?()
    end

    test "shows error message if field missing" do
      transformation_changeset = Transformation.changeset_for_draft(%{type: "remove"})
      assert {:ok, view, html} = render_transformation_form(transformation_changeset)

      form_update = %{
        "parameters" => %{"sourceField" => ""}
      }

      element(view, ".transformation-item") |> render_change(form_update)

      assert element(view, "#sourceField-error-msg", "Please enter a valid field to remove") |> has_element?()
    end

    test "shows parameter field value on load" do
      parameter_value = "something"
      transformation_changeset = Transformation.changeset_for_draft(%{type: "remove", parameters: %{sourceField: parameter_value}})

      assert {:ok, view, html} = render_transformation_form(transformation_changeset)

      field_id = build_field_id("sourceField")
      {:ok, document} = Floki.parse_document(html)

      assert parameter_value ==
               document
               |> Floki.attribute("##{field_id}", "value")
               |> Enum.join()
    end
  end

  defp render_transformation_form(transformation_changeset) do
    live_isolated(build_conn(), TransformationForm, session: %{"transformation_changeset" => transformation_changeset})
  end

  defp select_type(type, view) do
    click_value = %{"value" => type}
    element(view, ".transformation-type") |> render_click(click_value)
  end

  defp build_field_id(field_name) do
    "form_data_#{field_name}"
  end
end
