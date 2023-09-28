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
    show_additional_fields? = not is_nil(assigns.compare_to_null?) and not assigns.compare_to_null?
    show_all_comparison_options? = is_nil(assigns.compare_to_null?) or not assigns.compare_to_null?
    show_all_compare_to_types? = is_nil(assigns.allow_all_compare_to_types?) or assigns.allow_all_compare_to_types?

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
      <%= if show_all_comparison_options? do %>
        <div>
          <%= label(form, :conditionOperation, "Comparison", class: "label label--required", for: "transformation_condition_#{@id}__comparison") %>
          <%= select(form, :conditionOperation, ["", "Is Equal To", "Is Not Equal To", "Is Greater Than", "Is Less Than","Is Greater Than Or Equal To", "Is Less Than Or Equal To"], [value: get_in(form.source.changes, [:parameters, :conditionOperation]), id: "transformation_condition_#{@id}__comparison", class: "select transformation-type", required: true]) %>
          <%= ErrorHelpers.error_tag(form.source, :conditionOperation, bind_to_input: false, id: "#{@id}_transformation_condition_comparison_error") %>
        </div>
      <% else %>
        <div>
          <%= label(form, :conditionOperation, "Comparison", class: "label label--required", for: "transformation_condition_#{@id}__comparison") %>
          <%= select(form, :conditionOperation, ["", "Is Equal To", "Is Not Equal To"], [value: get_in(form.source.changes, [:parameters, :conditionOperation]), id: "transformation_condition_#{@id}__comparison", class: "select transformation-type", required: true]) %>
          <%= ErrorHelpers.error_tag(form.source, :conditionOperation, bind_to_input: false, id: "#{@id}_transformation_condition_comparison_error") %>
        </div>
      <% end %>
      <%= if show_all_compare_to_types? do %>
        <div>
          <%= label(form, :conditionCompareTo, "Compare to", class: "label label--required", for: "transformation_condition_#{@id}__compareTo") %>
          <%= select(form, :conditionCompareTo, ["", "Static Value", "Target Field", "Null or Empty"], [value: get_in(form.source.changes, [:parameters, :conditionCompareTo]), id: "transformation_condition_#{@id}__compareTo", class: "select transformation-type", required: true]) %>
          <%= ErrorHelpers.error_tag(form.source, :conditionCompareTo, bind_to_input: false, id: "#{@id}_transformation_condition_compareTo_error") %>
        </div>
      <% else %>
        <div>
          <%= label(form, :conditionCompareTo, "Compare to", class: "label label--required", for: "transformation_condition_#{@id}__compareTo") %>
          <%= select(form, :conditionCompareTo, ["", "Static Value", "Target Field"], [value: get_in(form.source.changes, [:parameters, :conditionCompareTo]), id: "transformation_condition_#{@id}__compareTo", class: "select transformation-type", required: true]) %>
          <%= ErrorHelpers.error_tag(form.source, :conditionCompareTo, bind_to_input: false, id: "#{@id}_transformation_condition_compareTo_error") %>
        </div>
      <% end %>
      <%= if show_additional_fields? do %>
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

    ~L"""
    <%= if show_input?(name, form) do %>
      <div class="transformation-field">
        <%= label(form, name, field.field_label, for: id, class: "transformation-field-label label label--required") %>
        <%= if not is_nil(options) do %>
          <%= select(form, name, options, [value: value, id: id, class: "select", prompt: "", required: true]) %>
        <% else %>
            <%= text_input(form, name, [value: value, id: id, class: "input transformation-form-fields", required: true]) %>
        <% end %>
        <%= ErrorHelpers.error_tag_with_label(form.source, name, field.field_label, bind_to_input: false, id: "#{id}_error") %>
      </div>
    <% end %>
    """
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

  defp show_input?(name, form) do
    not (name == :newValue and get_in(form.source.changes, [:parameters, :valueType]) == "null / empty")
  end
end
