defmodule AndiWeb.EditLiveView do
  use Phoenix.LiveView
  alias Phoenix.HTML.Form
  alias Phoenix.HTML.Link

  def render(assigns) do
    ~L"""
    <div class="edit-page">
      <%= Form.form_for @changest, "#", [class: "metadata-form"], fn f -> %>
        <div class="metadata-form__id">
          <%= Form.label(f, :id, "ID", class: "label label--required") %>
          <%= Form.text_input(f, :id, value: @dataset.id, class: "input") %>
        </div>
        <div class="metadata-form__title">
          <%= Form.label(f, :title, "Title of Dataset", class: "label label--required") %>
          <%= Form.text_input(f, :title, value: @dataset.business.dataTitle, class: "input") %>
        </div>
        <div class="metadata-form__format">
          <%= Form.label(f, :format, "Format", class: "label label--required") %>
          <%= Form.text_input(f, :format, value: @dataset.technical.sourceFormat, class: "input") %>
        </div>
      <% end %>
      <%= Link.link("Cancel", to: "/", class: "btn btn--cancel metadata-form__cancel-btn") %>
    </div>
    """
  end

  def mount(%{dataset: dataset}, socket) do
    change =
      Andi.DatasetSchema.changeset(%Andi.DatasetSchema{
        other: 1,
        technical: %Andi.DatasetTechnicalSchema{sourceFormat: "csv"},
        business: %Andi.DatasetBusinessSchema{dataTitle: "title"}
      })

    # change =
    #   Andi.DatasetSchema.changeset(%{
    #     other: 1
    #   })

    {:ok, assign(socket, changeset: change)}
  end

  # defp get_private(%{technical: %{private: true}}), do: "Private"
  # defp get_private(_), do: "Public"

  # defp get_keywords(%{business: %{keywords: nil}}), do: ""
  # defp get_keywords(%{business: %{keywords: keywords}}), do: Enum.intersperse(keywords, ", ")
end
