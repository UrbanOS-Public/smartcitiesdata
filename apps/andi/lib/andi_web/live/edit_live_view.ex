defmodule AndiWeb.EditLiveView do
  use Phoenix.LiveView
  alias Phoenix.HTML.Form
  alias Phoenix.HTML.Link

  def render(assigns) do
    # <%= Form.form_for @changest, "#", [class: "metadata-form"], fn f -> %>
    # <%= Form.form_for :metadata, "#", [class: "metadata-form"], fn f -> %>
    ~L"""
    <div class="edit-page">
    <%= f = Form.form_for @changeset, "#", [] %>
      <div class="metadata-form__id">
        <%= Form.label(f, :id, "ID", class: "label label--required") %>
        <%= Form.text_input(f, :id, value: @changeset.changes.other, class: "input") %>
      </div>
    <%= Link.link("Cancel", to: "/", class: "btn btn--cancel metadata-form__cancel-btn") %>
    </div>
    """

    #   <div class="metadata-form__title">
    #   <%= Form.label(f, :title, "Title of Dataset", class: "label label--required") %>
    #   <%= Form.text_input(f, :title, value: @changeset.business.dataTitle, class: "input") %>
    # </div>
    # <div class="metadata-form__format">
    #   <%= Form.label(f, :format, "Format", class: "label label--required") %>
    #   <%= Form.text_input(f, :format, value: @changeset.technical.sourceFormat, class: "input") %>
    # </div>
  end

  def mount(%{dataset: dataset}, socket) do
    # change =
    #   Andi.DatasetSchema.changeset(%Andi.DatasetSchema{
    #     other: 1,
    #     technical: %Andi.DatasetTechnicalSchema{sourceFormat: "csv"},
    #     business: %Andi.DatasetBusinessSchema{dataTitle: "title"}
    #   })

    # IO.inspect(dataset, label: "dataset")

    change =
      Andi.DatasetSchema.changeset(%{
        # other: 1,
        other: "1",
        technical: %{sourceFormat: "csv"},
        business: %{dataTitle: "title"}
      })

    IO.inspect(change, label: "change thing")

    {:ok, assign(socket, changeset: change)}
    # {:ok, assign(socket, dataset: dataset, changeset: change)}
    # {:ok, assign(socket, dataset: dataset)}
  end

  # defp get_private(%{technical: %{private: true}}), do: "Private"
  # defp get_private(_), do: "Public"

  # defp get_keywords(%{business: %{keywords: nil}}), do: ""
  # defp get_keywords(%{business: %{keywords: keywords}}), do: Enum.intersperse(keywords, ", ")
end
