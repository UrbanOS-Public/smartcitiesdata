defmodule AndiWeb.EditLiveView do
  use Phoenix.LiveView
  alias Phoenix.HTML.Form
  alias Phoenix.HTML.Link
  import AndiWeb.ErrorHelpers

  def render(assigns) do
    ~L"""
    <div class="edit-page">
      <%= f = Form.form_for @changeset, "#", [phx_change: :validate, class: "metadata-form"] %>
        <div class="metadata-form__title">
          <%= Form.inputs_for f, :business, fn fp -> %>
            <%= Form.label(fp, :title, "Title of Dataset", class: "label label--required") %>
            <%= Form.text_input(fp, :dataTitle, class: "input") %>
            <%= error_tag(fp, :dataTitle) %>
          <% end %>
        </div>
        <div class="metadata-form__description">
          <%= Form.inputs_for f, :business, fn fp -> %>
            <%= Form.label(fp, :description, "Description", class: "label label--required") %>
            <%= Form.textarea(fp, :description, class: "input textarea") %>
            <%= error_tag(fp, :description) %>
          <% end %>
        </div>
        <div class="metadata-form__format">
          <%= Form.inputs_for f, :technical, fn fp -> %>
            <%= Form.label(fp, :format, "Format", class: "label label--required") %>
            <%= Form.text_input(fp, :sourceFormat, class: "input") %>
            <%= error_tag(fp, :sourceFormat) %>
          <% end %>
        </div>
        <div class="metadata-form__maintainer-name">
          <%= Form.inputs_for f, :business, fn fp -> %>
            <%= Form.label(fp, :contactName, "Maintainer Name", class: "label label--required") %>
            <%= Form.text_input(fp, :contactName, class: "input") %>
            <%= error_tag(fp, :contactName) %>
          <% end %>
        </div>
        <div class="metadata-form__maintainer-email">
          <%= Form.inputs_for f, :business, fn fp -> %>
            <%= Form.label(fp, :contactEmail, "Maintainer Email", class: "label label--required") %>
            <%= Form.text_input(fp, :contactEmail, class: "input") %>
            <%= error_tag(fp, :contactEmail) %>
          <% end %>
        </div>
        <div class="metadata-form__release-date">
          <%= Form.inputs_for f, :business, fn fp -> %>
            <%= Form.label(fp, :issuedDate, "Release Date", class: "label label--required") %>
            <%= Form.text_input(fp, :issuedDate, class: "input") %>
            <%= error_tag(fp, :issuedDate) %>
          <% end %>
        </div>
        <div class="metadata-form__license">
          <%= Form.inputs_for f, :business, fn fp -> %>
            <%= Form.label(fp, :license, "License", class: "label label--required") %>
            <%= Form.text_input(fp, :license, class: "input") %>
            <%= error_tag(fp, :license) %>
          <% end %>
        </div>
        <div class="metadata-form__update-frequency">
          <%= Form.inputs_for f, :business, fn fp -> %>
            <%= Form.label(fp, :publishFrequency, "Update Frequency", class: "label label--required") %>
            <%= Form.text_input(fp, :publishFrequency, class: "input") %>
            <%= error_tag(fp, :publishFrequency) %>
          <% end %>
        </div>
        <div class="metadata-form__keywords">
          <%= Form.inputs_for f, :business, fn fp -> %>
            <%= Form.label(fp, :keywords, "Keywords", class: "label") %>
            <%= Form.text_input(fp, :keywords, value: get_keywords(Form.input_value(fp, :keywords)), class: "input") %>
            <div class="label label--inline">Separated by comma</div>
          <% end %>
        </div>
        <div class="metadata-form__last-updated">
          <%= Form.inputs_for f, :business, fn fp -> %>
            <%= Form.label(fp, :modifiedDate, "Last Updated", class: "label") %>
            <%= Form.text_input(fp, :modifiedDate, class: "input") %>
          <% end %>
        </div>
        <div class="metadata-form__spatial">
          <%= Form.inputs_for f, :business, fn fp -> %>
            <%= Form.label(fp, :spatial, "Spatial Boundaries", class: "label") %>
            <%= Form.text_input(fp, :spatial, class: "input") %>
          <% end %>
        </div>
        <div class="metadata-form__temporal">
          <%= Form.inputs_for f, :business, fn fp -> %>
            <%= Form.label(fp, :temporal, "Temporal Boundaries", class: "label") %>
            <%= Form.text_input(fp, :temporal, class: "input") %>
          <% end %>
        </div>
        <div class="metadata-form__organization">
          <%= Form.inputs_for f, :business, fn fp -> %>
            <%= Form.label(fp, :orgTitle, "Organization", class: "label label--required") %>
            <%= Form.text_input(fp, :orgTitle, class: "input") %>
            <%= error_tag(fp, :orgTitle) %>
          <% end %>
        </div>
        <div class="metadata-form__level-of-access">
          <%= Form.inputs_for f, :technical, fn fp -> %>
            <%= Form.label(fp, :private, "Level of Access", class: "label label--required") %>
            <%= Form.text_input(fp, :private, value: get_private(Form.input_value(fp, :private)), class: "input") %>
            <%= error_tag(fp, :private) %>
          <% end %>
        </div>
        <div class="metadata-form__language">
          <%= Form.inputs_for f, :business, fn fp -> %>
            <%= Form.label(fp, :language, "Language", class: "label") %>
            <%= Form.text_input(fp, :language, class: "input") %>
          <% end %>
        </div>
        <div class="metadata-form__homepage">
          <%= Form.inputs_for f, :business, fn fp -> %>
            <%= Form.label(fp, :homepage, "Data Homepage URL", class: "label") %>
            <%= Form.text_input(fp, :homepage, class: "input") %>
          <% end %>
        </div>
      </div>
      <%= Link.link("Cancel", to: "/", class: "btn btn--cancel metadata-form__cancel-btn") %>
    </div>
    """
  end

  def mount(%{dataset: dataset}, socket) do
    new_business = dataset.business |> Map.from_struct()
    new_technical = dataset.technical |> Map.from_struct()

    change =
      dataset
      |> Map.from_struct()
      |> Map.put(:business, new_business)
      |> Map.put(:technical, new_technical)
      |> Andi.DatasetSchema.changeset()

    {:ok, assign(socket, changeset: change)}
  end

  def handle_event("validate", %{"dataset_schema" => dataset_schema}, socket) do
    IO.inspect(dataset_schema, label: "schema")
    keyword_list = dataset_schema["business"]["keywords"] |> String.split()
    dataset_schema = put_in(dataset_schema, ["business", "keywords"], keyword_list)

    change = Andi.DatasetSchema.changeset(dataset_schema)
    {:noreply, assign(socket, changeset: change)}
  end

  defp get_private(true), do: "Private"
  defp get_private(_), do: "Public"

  defp get_keywords(nil), do: ""
  defp get_keywords(keywords), do: Enum.intersperse(keywords, ", ")
end
