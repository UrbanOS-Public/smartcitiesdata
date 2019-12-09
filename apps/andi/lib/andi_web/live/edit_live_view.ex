defmodule AndiWeb.EditLiveView do
  use Phoenix.LiveView
  alias Phoenix.HTML.Form
  alias Phoenix.HTML.Link

  require IEx

  def render(assigns) do
    ~L"""
    <div class="edit-page">
      <%= f = Form.form_for @changeset, "#", [phx_change: :dataset_edit] %>

        <div class="metadata-form__id">
          <%= Form.label(f, :id, "ID", class: "label label--required") %>
          <%= Form.text_input(f, :other) %>
        </div>

        <%= Form.inputs_for f, :technical, fn fp -> %>
          <%= Form.label(fp, :title, "Source Format", class: "label label--required") %>
          <%= Form.text_input(fp, :sourceFormat) %>
        <% end %>

        <%= Form.inputs_for f, :business, fn fp -> %>
          <%= Form.label(fp, :title, "Dataset Title", class: "label label--required") %>
          <%= Form.text_input(fp, :dataTitle) %>
        <% end %>

        <%= Link.link("Cancel", to: "/", class: "btn btn--cancel metadata-form__cancel-btn") %>
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

  def handle_event("dataset_edit", event, socket) do
    IO.inspect(event, label: "handle_event event:")
    {:noreply, socket}
  end

  # def handle_event("dataset", event, %{assigns: %{changeset: %{changes: existing}}} = socket) do
  #   # IO.inspect(event, label: "handle event:")
  #   IO.inspect(existing, label: "existing:")
  #   change = Andi.DatasetSchema.changeset(event["dataset_schema"])

  #   IO.inspect(change, label: "change")
  #   merged = Map.merge(existing, change.changes)

  #   IO.inspect(merged, label: "merged")
  #   {:noreply, assign(socket, changeset: Andi.DatasetSchema.changeset(merged))}
  # end

  # defp get_private(%{technical: %{private: true}}), do: "Private"
  # defp get_private(_), do: "Public"

  # defp get_keywords(%{business: %{keywords: nil}}), do: ""
  # defp get_keywords(%{business: %{keywords: keywords}}), do: Enum.intersperse(keywords, ", ")
end
