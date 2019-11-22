defmodule AndiWeb.EditLiveView do
  # TODO make default view useful
  use Phoenix.LiveView
  alias AndiWeb.Router.Helpers, as: Routes
  alias Andi.DatasetCache
  alias Phoenix.HTML.Form
  alias Phoenix.HTML.Link

  # TODO What's the difference between Release Date and LastUpdated again?
  def render(assigns) do
    ~L"""
    <%= Form.form_for :metadata, "#", [phx_change: :validate, class: "metadata-form"], fn f -> %>
      <div class="metadata-form__title">
        <%= Form.label(f, :title, "Title of Dataset") %>
        <%= Form.text_input(f, :title, value: @dataset.business.dataTitle) %>
      </div>
      <div class="metadata-form__description">
        <%= Form.label(f, :description, "Description") %>
        <%= Form.textarea(f, :description, value: @dataset.business.description) %>
      </div>
      <div class="metadata-form__format">
        <%= Form.label(f, :format, "Format") %>
        <%= Form.text_input(f, :format, value: @dataset.technical.sourceFormat) %>
      </div>
      <div class="metadata-form__maintainer-name">
        <%= Form.label(f, :authorName, "Maintainer Name") %>
        <%= Form.text_input(f, :authorName, value: @dataset.business.contactName) %>
      </div>
      <div class="metadata-form__maintainer-email">
        <%= Form.label(f, :authorEmail, "Maintainer Email") %>
        <%= Form.text_input(f, :authorEmail, value: @dataset.business.contactEmail) %>
      </div>
      <div class="metadata-form__release-date">
        <%= Form.label(f, :modifiedDate, "Release Date") %>
        <%= Form.text_input(f, :modifiedDate, value: @dataset.business.modifiedDate) %>
      </div>
      <div class="metadata-form__license">
        <%= Form.label(f, :license, "License") %>
        <%= Form.text_input(f, :license, value: @dataset.business.license) %>
      </div>
      <div class="metadata-form__update-frequency">
        <%= Form.label(f, :publishFrequency, "Update Frequency") %>
        <%= Form.text_input(f, :publishFrequency, value: @dataset.business.publishFrequency) %>
      </div>
      <div class="metadata-form__keywords">
        <%= Form.label(f, :keywords, "Keywords") %>
        <%= Form.text_input(f, :keywords, value: @dataset.business.keywords) %>
      </div>
      <div class="metadata-form__last-updated">
        <%= Form.label(f, :modifiedDate, "Last Updated") %>
        <%= Form.text_input(f, :modifiedDate, value: @dataset.business.modifiedDate) %>
      </div>
      <div class="metadata-form__spatial">
        <%= Form.label(f, :spatial, "Spatial Boundaries") %>
        <%= Form.text_input(f, :spatial, value: @dataset.business.spatial) %>
      </div>
      <div class="metadata-form__temporal">
        <%= Form.label(f, :temporal, "Temporal Boundaries") %>
        <%= Form.text_input(f, :temporal, value: @dataset.business.temporal) %>
      </div>
      <div class="metadata-form__organization">
        <%= Form.label(f, :orgTitle, "Organization") %>
        <%= Form.text_input(f, :orgTitle, value: @dataset.business.orgTitle) %>
      </div>
      <div class="metadata-form__level-of-access">
        <%= Form.label(f, :private, "Level of Access") %>
        <%= Form.text_input(f, :private, value: get_private(@dataset)) %>
      </div>
      <div class="metadata-form__language">
        <%= Form.label(f, :language, "Language") %>
        <%= Form.text_input(f, :language, value: @dataset.business.language) %>
      </div>
      <div class="metadata-form__homepage">
        <%= Form.label(f, :homepage, "Data Homepage URL") %>
        <%= Form.text_input(f, :homepage, value: @dataset.business.homepage) %>
      </div>
    <% end %>
    <%= Link.link("Cancel", to: "/", class: "btn btn--cancel") %>
    """
  end

  def mount(%{"id" => id}, socket) do
    %{"dataset" => dataset} = DatasetCache.get(id)
    {:ok, assign(socket, dataset: dataset, inc: 0)}
  end

  def get_private(%{technical: %{private: true}}), do: "private"
  def get_private(_), do: "public"

  def handle_event("validate", args, socket) do
    IO.inspect(args)
    {:noreply, socket}
  end
end
