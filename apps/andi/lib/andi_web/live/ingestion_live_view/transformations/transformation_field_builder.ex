defmodule AndiWeb.IngestionLiveView.Transformations.TransformationFieldBuilder do
  import Phoenix.HTML.Form
  import Phoenix.LiveView.Helpers

  alias AndiWeb.ErrorHelpers

  def build_input(field, assigns, form, id) do
    name = String.to_atom(field.field_name)
    value = get_in(form.source.changes, [:parameters, name])
    options = Map.get(field, :options)

    ~L"""
    <div class="transformation-field">
      <%= label(form, name, field.field_label, for: id, class: "transformation-field-label label label--required") %>
      <%= if not is_nil(options) do %>
        <%= select(form, name, options, [id: id, class: "select", prompt: "", required: true]) %>
      <% else %>
        <%= text_input(form, name, [value: value, id: id, class: "input transformation-form-fields", required: true]) %>
      <% end %>
      <%= ErrorHelpers.error_tag_with_label(form.source, name, field.field_label, bind_to_input: false, id: "#{id}_error") %>
    </div>
    """
  end
end
