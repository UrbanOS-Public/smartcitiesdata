defmodule AndiWeb.EditLiveView do
  use Phoenix.LiveView
  alias Phoenix.HTML.Form
  alias Phoenix.HTML.Link

  def render(assigns) do
    ~L"""
    <div class="edit-page">
      <%= Form.form_for :metadata, "#", [class: "metadata-form"], fn f -> %>
        <div class="metadata-form__title">
          <%= Form.label(f, :title, "Title of Dataset", class: "label label--required") %>
          <%= Form.text_input(f, :title, value: @dataset.business.dataTitle, class: "input") %>
        </div>
        <div class="metadata-form__description">
          <%= Form.label(f, :description, "Description", class: "label label--required") %>
          <%= Form.textarea(f, :description, value: @dataset.business.description, class: "input textarea") %>
        </div>
        <div class="metadata-form__format">
          <%= Form.label(f, :format, "Format", class: "label label--required") %>
          <%= Form.text_input(f, :format, value: @dataset.technical.sourceFormat, class: "input") %>
        </div>
        <div class="metadata-form__maintainer-name">
          <%= Form.label(f, :contactName, "Maintainer Name", class: "label label--required") %>
          <%= Form.text_input(f, :contactName, value: @dataset.business.contactName, class: "input") %>
        </div>
        <div class="metadata-form__maintainer-email">
          <%= Form.label(f, :contactEmail, "Maintainer Email", class: "label label--required") %>
          <%= Form.text_input(f, :contactEmail, value: @dataset.business.contactEmail, class: "input") %>
        </div>
        <div class="metadata-form__release-date">
          <%= Form.label(f, :issuedDate, "Release Date", class: "label label--required") %>
          <%= Form.text_input(f, :issuedDate, value: @dataset.business.issuedDate, class: "input") %>
        </div>
        <div class="metadata-form__license">
          <%= Form.label(f, :license, "License", class: "label label--required") %>
          <%= Form.text_input(f, :license, value: @dataset.business.license, class: "input") %>
        </div>
        <div class="metadata-form__update-frequency">
          <%= Form.label(f, :publishFrequency, "Update Frequency", class: "label label--required") %>
          <%= Form.text_input(f, :publishFrequency, value: @dataset.business.publishFrequency, class: "input") %>
        </div>
        <div class="metadata-form__keywords">
          <%= Form.label(f, :keywords, "Keywords", class: "label") %>
          <%= Form.text_input(f, :keywords, value: get_keywords(@dataset), class: "input") %>
          <div class="label label--inline">Separated by comma</div>
        </div>
        <div class="metadata-form__last-updated">
          <%= Form.label(f, :modifiedDate, "Last Updated", class: "label") %>
          <%= Form.text_input(f, :modifiedDate, value: @dataset.business.modifiedDate, class: "input") %>
        </div>
        <div class="metadata-form__spatial">
          <%= Form.label(f, :spatial, "Spatial Boundaries", class: "label") %>
          <%= Form.text_input(f, :spatial, value: @dataset.business.spatial, class: "input") %>
        </div>
        <div class="metadata-form__temporal">
          <%= Form.label(f, :temporal, "Temporal Boundaries", class: "label") %>
          <%= Form.text_input(f, :temporal, value: @dataset.business.temporal, class: "input") %>
        </div>
        <div class="metadata-form__organization">
          <%= Form.label(f, :orgTitle, "Organization", class: "label label--required") %>
          <%= Form.text_input(f, :orgTitle, value: @dataset.business.orgTitle, class: "input") %>
        </div>
        <div class="metadata-form__level-of-access">
          <%= Form.label(f, :private, "Level of Access", class: "label label--required") %>
          <%= Form.text_input(f, :private, value: get_private(@dataset), class: "input") %>
        </div>
        <div class="metadata-form__language">
          <%= Form.label(f, :language, "Language", class: "label") %>
          <%= Form.text_input(f, :language, value: @dataset.business.language, class: "input") %>
        </div>
        <div class="metadata-form__homepage">
          <%= Form.label(f, :homepage, "Data Homepage URL", class: "label") %>
          <%= Form.text_input(f, :homepage, value: @dataset.business.homepage, class: "input") %>
        </div>
      <% end %>
      <%= Link.link("Cancel", to: "/", class: "btn btn--cancel metadata-form__cancel-btn") %>
    </div>
    """
  end

  def mount(%{dataset: dataset}, socket) do
    {:ok, assign(socket, dataset: dataset)}
  end

  defp get_private(%{technical: %{private: true}}), do: "Private"
  defp get_private(_), do: "Public"

  defp get_keywords(%{business: %{keywords: nil}}), do: ""
  defp get_keywords(%{business: %{keywords: keywords}}), do: Enum.intersperse(keywords, ", ")
end
