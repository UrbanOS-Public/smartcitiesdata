defmodule AndiWeb.IngestionLiveView.Transformations.TransformationFieldBuilder do
  import Phoenix.HTML.Form
  import Phoenix.LiveView.Helpers

  alias AndiWeb.Helpers.MetadataFormHelpers
  alias AndiWeb.ErrorHelpers
  alias AndiWeb.Views.DisplayNames
  alias Transformers.TransformationFields

  def build_condition_form(assigns, form) do
    show_static_field = not is_nil(assigns.static?) and assigns.static?
    show_target_field = not is_nil(assigns.static?) and not assigns.static?
    show_date_format_fields = not is_nil(assigns.date?) and assigns.date?

    ~L"""
    <h3><b>IF</b></h3>
    <fieldset class="transformation-form__condition-fields">
      <div>
        <%= label(form, :sourceConditionField, "Comparison Field", class: "label label--required", for: "transformation_condition_#{@id}__sourcefield") %>
        <%= text_input(form, :sourceConditionField, [value: get_in(form.source.changes, [:parameters, :sourceConditionField]), id: "transformation_condition_#{@id}__sourcefield", class: "input transformation-form-fields", required: true, aria_label: "Transformation Condition Comparison Field"]) %>
        <%= ErrorHelpers.error_tag(form, :sourceConditionField, bind_to_input: false, id: "#{@id}_transformation_condition_sourcefield_error") %>
      </div>
      <div>
        <%= label(form, :conditionDataType, "Comparison Value Type", class: "label label--required", for: "transformation_condition_#{@id}__comparisonType") %>
        <%= select(form, :conditionDataType, ["", "String", "Number", "DateTime"], [value: get_in(form.source.changes, [:parameters, :conditionDataType]), id: "transformation_condition_#{@id}__comparisonType", class: "select transformation-type", required: true]) %>
        <%= ErrorHelpers.error_tag(form.source, :conditionDataType, bind_to_input: false, id: "#{@id}_transformation_condition_comparisonType_error") %>
      </div>
      <div>
        <%= label(form, :conditionOperation, "Comparison", class: "label label--required", for: "transformation_condition_#{@id}__comparison") %>
        <%= select(form, :conditionOperation, ["", "Is Equal To", "Is Not Equal To", "Is Greater Than", "Is Less Than"], [value: get_in(form.source.changes, [:parameters, :conditionOperation]), id: "transformation_condition_#{@id}__comparison", class: "select transformation-type", required: true]) %>
        <%= ErrorHelpers.error_tag(form.source, :conditionOperation, bind_to_input: false, id: "#{@id}_transformation_condition_comparison_error") %>
      </div>
      <div>
        <%= label(form, :conditionCompareTo, "Compare to", class: "label label--required", for: "transformation_condition_#{@id}__compareTo") %>
        <%= select(form, :conditionCompareTo, ["", "Static Value", "Target Field"], [value: get_in(form.source.changes, [:parameters, :conditionCompareTo]), id: "transformation_condition_#{@id}__compareTo", class: "select transformation-type", required: true]) %>
        <%= ErrorHelpers.error_tag(form.source, :conditionCompareTo, bind_to_input: false, id: "#{@id}_transformation_condition_compareTo_error") %>
      </div>
      <%= if show_static_field or show_target_field do %>
        <%= if show_static_field do %>
          <div>
            <%= label(form, :targetConditionValue, "Value", class: "label label--required", for: "transformation_condition_#{@id}__targetValue") %>
            <%= text_input(form, :targetConditionValue, [value: get_in(form.source.changes, [:parameters, :targetConditionValue]), id: "transformation_condition_#{@id}__targetValue", class: "input transformation-form-fields", required: true, aria_label: "Transformation Condition Target Value"]) %>
            <%= ErrorHelpers.error_tag(form, :targetConditionValue, bind_to_input: false, id: "#{@id}_transformation_condition_targetValue_error") %>
          </div>
        <% end %>
        <%= if show_target_field do %>
          <div>
            <%= label(form, :targetConditionField, "Target Field", class: "label label--required", for: "transformation_condition_#{@id}__targetField") %>
            <%= text_input(form, :targetConditionField, [value: get_in(form.source.changes, [:parameters, :targetConditionField]), id: "transformation_condition_#{@id}__targetField", class: "input transformation-form-fields", required: true, aria_label: "Transformation Condition Target Field"]) %>
            <%= ErrorHelpers.error_tag(form, :targetConditionField, bind_to_input: false, id: "#{@id}_transformation_condition_targetField_error") %>
          </div>
        <% end %>
        <%= if show_date_format_fields do %>
          <div>
            <%= label(form, :conditionSourceDateFormat, "Source Date Format", class: "label label--required", for: "transformation_condition_#{@id}__sourceDateFormat") %>
            <%= text_input(form, :conditionSourceDateFormat, [value: get_in(form.source.changes, [:parameters, :conditionSourceDateFormat]), id: "transformation_condition_#{@id}__sourceDateFormat", class: "input transformation-form-fields", required: true, aria_label: "Transformation Condition Source Date Format"]) %>
            <%= ErrorHelpers.error_tag(form, :conditionSourceDateFormat, bind_to_input: false, id: "#{@id}_transformation_condition_sourceDateFormat_error") %>
          </div>
          <div>
            <%= label(form, :conditionTargetDateFormat, "Target Date Format", class: "label label--required", for: "transformation_condition_#{@id}__targetDateFormat") %>
            <%= text_input(form, :conditionTargetDateFormat, [value: get_in(form.source.changes, [:parameters, :conditionTargetDateFormat]), id: "transformation_condition_#{@id}__targetDateFormat", class: "input transformation-form-fields", required: true, aria_label: "Transformation Condition Target Date Format"]) %>
            <%= ErrorHelpers.error_tag(form, :conditionTargetDateFormat, bind_to_input: false, id: "#{@id}_transformation_condition_targetDateFormat_error") %>
          </div>
        <% end %>
      <% end %>
    </fieldset>
    <div>
      <h3><b>THEN</b></h3>
      <fieldset class="transformation-form__condition-fields">
        <%= build_transformation_form(assigns, form, true) %>
      </fieldset>
    </div>
    """
  end

  def build_transformation_form(assigns, form, condition?) do
    from_condition = if condition?, do: "conditional", else: "default"

    ~L"""
    <div>
      <%= label(form, :type, DisplayNames.get(:transformationType), class: "label label--required", for: "transformation_#{@id}__type_#{from_condition}") %>
      <%= select(form, :type, get_transformation_types(), [id: "transformation_#{@id}__type_#{from_condition}", class: "select transformation-type", required: true]) %>
      <%= ErrorHelpers.error_tag(form.source, :type, bind_to_input: false, id: "#{@id}_transformation_type_error") %>
    </div>
    <div class="transformation-form__fields">
      <%= for field <- get_fields(input_value(form, :type)) do %>
        <%= build_input(field, assigns, form, "transformation_#{@id}__#{field.field_name}_#{from_condition}") %>
      <% end %>
    </div>
    """
  end

  def build_input(field, assigns, form, id) do
    name = String.to_atom(field.field_name)
    value = get_in(form.source.changes, [:parameters, name])

    options = Map.get(field, :options)

    show_field =
      if name != :conversionDateFormat or (name == :conversionDateFormat and conversion_type_has_datetime?(assigns)),
        do: "expanded",
        else: "collapsed"

    ~L"""
    <div class="transformation-field transformation-form__section--<%= show_field %>">
      <%= label(form, name, field.field_label, for: id, class: "transformation-field-label label label--required") %>
      <%= if not is_nil(options) do %>
        <%= select(form, name, options, [value: value, id: id, class: "select", prompt: "", required: true]) %>
      <% else %>
        <%= text_input(form, name, [value: value, id: id, class: "input transformation-form-fields", required: true]) %>
        <% end %>
      <%= generate_validation_message(form, name, field, assigns, id) %>
    </div>
    """
  end

  defp generate_validation_message(form, name, field, assigns, id) do
    ~L"""
      <div>
      <%= ErrorHelpers.error_tag_with_label(form.source, name, field.field_label, bind_to_input: false, id: "#{id}_error") %>
      <%= if conversion_type_has_datetime?(assigns) do %>
        <%= show_datetime_type_warning_message(assigns, form, name, field, id) %>
      <% end %>
      </div>
    """
  end

  defp show_datetime_type_warning_message(assigns, form, name, field, id) do
    [source_type, target_type] = get_source_and_target_types(assigns)

    if (name == :sourceType and target_type == "datetime" and source_type != "string") or
         (name == :targetType and source_type == "datetime" and target_type != "string") do
      ~L"""
        <span class="error-msg" id="<%= id %>_typeError">
          *datetimes can only be converted to strings
        </span>
      """
    end
  end

  defp map_to_dropdown_options(options) do
    Enum.map(options, fn {actual_value, description} ->
      [key: description, value: actual_value]
    end)
  end

  defp get_transformation_types(), do: map_to_dropdown_options(MetadataFormHelpers.get_transformation_type_options())

  defp get_fields(transformation_type) do
    TransformationFields.fields_for(transformation_type)
  end

  defp conversion_type_has_datetime?(assigns) do
    get_source_and_target_types(assigns) |> Enum.any?(fn type -> type == "datetime" end)
  end

  defp get_source_and_target_types(assigns) do
    params = Map.get(assigns.transformation_changeset.changes, :parameters)

    if not is_nil(params) do
      source_type = Map.get(params, :sourceType)
      target_type = Map.get(params, :targetType)
      [source_type, target_type]
    else
      [nil, nil]
    end
  end
end
