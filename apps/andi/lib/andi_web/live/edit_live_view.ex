defmodule AndiWeb.EditLiveView do
  use Phoenix.LiveView
  alias Phoenix.HTML.Form
  alias Phoenix.HTML.Link
  import AndiWeb.ErrorHelpers

  def render(assigns) do
    # phx_validation or phx_submit
    ~L"""
    <div class="edit-page">
      <%= f = Form.form_for @changeset, "#", [phx_submit: :dataset_submit, phx_change: :validate] %>

        <div class="metadata-form__id">
          <%= Form.label(f, :id, "ID", class: "label label--required") %>
          <%= Form.text_input(f, :other, [class: "input"]) %>
          <%= error_tag(f, :other) %>
        </div>

        <%= Form.inputs_for f, :technical, fn fp -> %>
          <%= Form.label(fp, :title, "Source Format", class: "label label--required") %>
          <%= Form.text_input(fp, :sourceFormat, [class: "input"]) %>
        <% end %>

        <%= Form.inputs_for f, :business, fn fp -> %>
          <%= Form.label(fp, :title, "Dataset Title", class: "label label--required") %>
          <%= Form.text_input(fp, :dataTitle, [class: "input"]) %>
        <% end %>
        <div>
          <%= Link.link("Cancel", to: "/", class: "btn btn--cancel metadata-form__cancel-btn") %>
        </div>
        <div>
          <%= Form.submit "Submit" %>
        </div>
    </div>
    """
  end

  def mount(%{dataset: %{id: id, technical: technical, business: business}}, socket) do
    change =
      %{
        other: id,
        technical: %{sourceFormat: technical.sourceFormat},
        business: %{dataTitle: business.dataTitle}
      }
      |> Andi.DatasetSchema.changeset()

    {:ok, assign(socket, changeset: change)}
  end

  def handle_event("validate", %{"dataset_schema" => dataset_schema}, socket) do
    change = Andi.DatasetSchema.changeset(dataset_schema)
    {:noreply, assign(socket, changeset: change)}
  end

  def handle_event("dataset_submit", %{"dataset_schema" => dataset_schema}, socket) do
    change = Andi.DatasetSchema.changeset(dataset_schema)
    {:noreply, assign(socket, changeset: change)}
  end

  # defp get_private(%{technical: %{private: true}}), do: "Private"
  # defp get_private(_), do: "Public"

  # defp get_keywords(%{business: %{keywords: nil}}), do: ""
  # defp get_keywords(%{business: %{keywords: keywords}}), do: Enum.intersperse(keywords, ", ")
end
