defmodule AndiWeb.IngestionLiveView.Transformations.TransformationFieldBuilder do
  import Phoenix.HTML.Form
  import Phoenix.LiveView.Helpers

  alias AndiWeb.ErrorHelpers

  def build_input(%{field_type: "string"} = field, assigns, form) do
    name = String.to_atom(field.field_name)
    value = get_in(form.source.changes, [:parameters, name])

    ~L"""
    <div class="transformation-field">
      <%= label(form, name, field.field_label, class: "transformation-field-label label label--required") %>
      <%= text_input(form, name, value: value, class: "input transformation-form-fields", phx_debounce: "1000") %>
      <%= ErrorHelpers.error_tag_with_label(form.source, name, field.field_label, bind_to_input: false) %>
    </div>
    """
  end
end
