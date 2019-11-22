defmodule AndiWeb.EditLiveView do
  # TODO make default view useful
  use Phoenix.LiveView
  alias AndiWeb.Router.Helpers, as: Routes
  alias Andi.DatasetCache
  alias Phoenix.HTML.Form

  # TODO What's the difference between Release Date and LastUpdated again?
  def render(assigns) do
    ~L"""
    <%= Form.form_for :metadata, "#", [phx_change: :validate], fn f -> %>
      <%= Form.label(f, :title, "Title of Dataset") %>
      <%= Form.text_input(f, :title, value: @dataset.business.dataTitle) %>
      <%= Form.label(f, :description, "Description") %>
      <%= Form.textarea(f, :description, value: @dataset.business.description) %>
      <%= Form.label(f, :format, "Format") %>
      <%= Form.text_input(f, :format, value: @dataset.technical.sourceFormat) %>
      <%= Form.label(f, :authorName, "Maintainer Name") %>
      <%= Form.text_input(f, :authorName, value: @dataset.business.contactName) %>
      <%= Form.label(f, :authorEmail, "Maintainer Email") %>
      <%= Form.text_input(f, :authorEmail, value: @dataset.business.contactEmail) %>
      <%= Form.label(f, :modifiedDate, "Release Date") %>
      <%= Form.text_input(f, :modifiedDate, value: @dataset.business.modifiedDate) %>
      <%= Form.label(f, :license, "License") %>
      <%= Form.text_input(f, :license, value: @dataset.business.license) %>
      <%= Form.label(f, :publishFrequency, "Update Frequency") %>
      <%= Form.text_input(f, :publishFrequency, value: @dataset.business.publishFrequency) %>
      <%= Form.label(f, :keywords, "Keywords") %>
      <%= Form.text_input(f, :keywords, value: @dataset.business.keywords) %>
      <%= Form.label(f, :modifiedDate, "Last Updated") %>
      <%= Form.text_input(f, :modifiedDate, value: @dataset.business.modifiedDate) %>
      <%= Form.label(f, :spatial, "Spatial Boundaries") %>
      <%= Form.text_input(f, :spatial, value: @dataset.business.spatial) %>
      <%= Form.label(f, :temporal, "Temporal Boundaries") %>
      <%= Form.text_input(f, :temporal, value: @dataset.business.temporal) %>
      <%= Form.label(f, :orgTitle, "Organization") %>
      #TODO: This needs to be replaced with an org selection dropdown in the next card
      <%= Form.text_input(f, :orgTitle, value: @dataset.business.orgTitle) %>
      <%= Form.label(f, :private, "Level of Access") %>
      <%= Form.text_input(f, :private, value: get_private(@dataset.technical.private)) %>
      <%= Form.label(f, :language, "Language") %>
      <%= Form.text_input(f, :language, value: @dataset.business.language) %>
      <%= Form.label(f, :homepage, "Data Homepage URL") %>
      <%= Form.text_input(f, :homepage, value: @dataset.business.homepage) %>
    <% end %>
    """
  end

  def mount(%{"id" => id}, socket) do
    %{"dataset" => dataset} = DatasetCache.get(id)
    {:ok, assign(socket, dataset: dataset)}
  end

  def get_private(%{technical: %{private: true}}), do: "private"
  def get_private(_), do: "public"

  def handle_event("validate", args, socket) do
    IO.inspect(args)
    {:noreply, socket}
  end
end
