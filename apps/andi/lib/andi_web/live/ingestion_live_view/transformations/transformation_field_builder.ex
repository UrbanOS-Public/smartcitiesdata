defmodule AndiWeb.IngestionLiveView.Transformations.TransformationFieldBuilder do
  import Phoenix.HTML.Form
  import Phoenix.LiveView.Helpers

  alias AndiWeb.ErrorHelpers

  def build_input(%{field_type: "string"} = field, assigns, form) do
    transformation_id = get_transformation_id(assigns)
    field_id = build_field_id(transformation_id, field.field_name)
    name = "form_data[parameters][#{field.field_name}]"

    ~L"""
    <div class="transformation-field">
      <%= label(form, field_id, field.field_label, class: "transformation-field-label label label--required") %>
      <%= text_input(form, field_id, name: name, class: "input transformation-form-fields", phx_debounce: "1000") %>
      <%= ErrorHelpers.error_tag_with_label(form.source, field.field_name, field.field_label, bind_to_input: false) %>
    </div>
    """
  end

  defp get_transformation_id(assigns) do
    assigns.transformation_changeset.changes.id
  end

  defp build_field_id(transformation_id, field_name) do
    field_id_content = "transformation-#{transformation_id}-#{field_name}"
    String.to_atom(field_id_content)
  end
end
