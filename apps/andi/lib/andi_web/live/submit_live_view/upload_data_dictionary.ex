defmodule AndiWeb.SubmitLiveView.UploadDataDictionary do
  @moduledoc """
    LiveComponent for public submissions of datasets
  """
  use Properties, otp_app: :andi
  use Phoenix.LiveView
  use AndiWeb.FormSection, schema_module: AndiWeb.InputSchemas.DatasetLinkFormSchema
  use Tesla
  import Phoenix.HTML.Form
  alias AndiWeb.Router.Helpers, as: Routes
  alias AndiWeb.ErrorHelpers
  alias AndiWeb.InputSchemas.DatasetLinkFormSchema
  alias AndiWeb.Helpers.FormTools
  alias ExAws.S3

  plug Tesla.Middleware.Timeout, timeout: 20_000

  @bucket_path "samples/"

  getter(:hosted_bucket, generic: true)

  def mount(_, %{"dataset" => dataset}, socket) do
    new_upload_data_dictionary_changeset = AndiWeb.InputSchemas.DatasetLinkFormSchema.changeset_from_andi_dataset(dataset)

    send(socket.parent_pid, {:update_dataset_link_status, new_upload_data_dictionary_changeset.valid?})

    AndiWeb.Endpoint.subscribe("toggle-visibility")
    AndiWeb.Endpoint.subscribe("form-save")

    {:ok,
     assign(socket,
       changeset: new_upload_data_dictionary_changeset,
       visibility: "collapsed",
       validation_status: "collapsed",
       dataset_id: dataset.id,
       loading_schema: false
     )}
  end

  def render(assigns) do
    action =
      case assigns.visibility do
        "collapsed" -> "EDIT"
        "expanded" -> "MINIMIZE"
      end

    loader_visibility =
      case assigns.loading_schema do
        true -> "loading"
        false -> "hidden"
      end

    ~L"""
    <div id="upload-sample-dataset-form" class="form-component">
      <div class="component-header" phx-click="toggle-component-visibility">
        <div class="section-number">
          <h3 class="component-number component-number--<%= @validation_status %> component-number--<%= @visibility %>">2</h3>
          <div class="component-number-status--<%= @validation_status %>"></div>
        </div>

        <div class="component-title full-width">
          <h2 class="component-title-text component-title-text--<%= @visibility %>">Upload Dataset Sample</h2>
          <div class="component-title-action">
            <div class="component-title-action-text--<%= @visibility %>"><%= action %></div>
            <div class="component-title-icon--<%= @visibility %>"></div>
          </div>
        </div>
      </div>

      <div class="form-section">
        <%= f = form_for @changeset, "#", [phx_change: :validate, as: :form_data, multipart: true] %>
       
          <div class="component-edit-section--<%= @visibility %>">
            <div class="url-form-header">
              <h4>Dataset sample may not contain any Personally Identifiable Information (PII). If the data is found to contain PII, it will be rejected.</h4>
            </div>
            <div class="upload-section">

              <div class="upload-data-dictionary-form__file-upload">
                <div class="file-input-button">
                  <%= label(f, :sample_dataset, "Select File", class: "file-upload-label") %>
                  <%= file_input(f, :sample_dataset, phx_hook: "readFile", accept: "text/csv, application/json") %>
                </div>
                <div class="sample-file-display">
                  <%= hidden_input(f, :datasetLink) %>
                  <%= input_value(f, :datasetLink) |> parse_dataset_link() %>
                  <%= ErrorHelpers.error_tag(f, :datasetLink, bind_to_input: false) %>
                </div>

                <button type="button" id="reader-cancel" class="file-upload-cancel-button file-upload-cancel-button--<%= loader_visibility %> btn">Cancel</button>
                <div class="loader data-dictionary-form__loader data-dictionary-form__loader--<%= loader_visibility %>"></div>
              </div>
          </div>

            <div class="edit-button-group form-grid">
              <div class="edit-button-group__cancel-btn">
                <a href="#data-dictionary-form" id="back-button" class="btn btn--back btn--large" phx-click="toggle-component-visibility" phx-value-component-expand="metadata_form">Back</a>
                <button type="button" class="btn btn--large" phx-click="cancel-edit">Cancel</button>
              </div>

              <div class="edit-button-group__save-btn">
                <a href="#review_submission" id="next-button" class="btn btn--next btn--large btn--action" phx-click="toggle-component-visibility" phx-value-component-expand="data_dictionary_form">Next</a>
              </div>
            </div>
          </div>
        </form>
      </div>
    </div>
    """
  end

  def handle_event("validate", _, socket) do
    {:noreply, socket}
  end

  def handle_info(
        %{topic: "toggle-visibility", payload: %{expand: "metadata_form", dataset_id: dataset_id}},
        %{assigns: %{dataset_id: dataset_id}} = socket
      ) do
    {:noreply, assign(socket, visibility: "expanded") |> update_validation_status()}
  end

  def handle_info(%{topic: "toggle-visibility"}, socket) do
    {:noreply, socket}
  end

  def handle_event("file_upload", %{"fileType" => file_type}, socket)
      when file_type not in ["text/csv", "application/json", "application/vnd.ms-excel"] do
    new_changeset =
      socket.assigns.changeset
      |> reset_changeset_errors()
      |> Ecto.Changeset.add_error(:datasetLink, "File type must be CSV or JSON")
      |> Map.put(:action, :update)

    {:noreply, assign(socket, changeset: new_changeset, loading_schema: false)}
  end

  def handle_event("file_upload", %{"fileSize" => file_size}, socket) when file_size > 200_000_000 do
    new_changeset =
      socket.assigns.changeset
      |> reset_changeset_errors()
      |> Ecto.Changeset.add_error(:datasetLink, "File size must be less than 200MB")
      |> Map.put(:action, :update)

    {:noreply, assign(socket, changeset: new_changeset, loading_schema: false)}
  end

  def handle_event("file_upload", %{"file" => file, "fileName" => file_name, "fileType" => file_type}, socket)
      when file_type in ["text/csv", "application/vnd.ms-excel"] do
    dataset_id = socket.assigns.dataset_id
    dataset_link = "#{@bucket_path}#{dataset_id}/#{file_name}"

    with {:ok, presigned_url} <- presigned_url(dataset_id, file_name),
         {:ok, _} <- upload_sample_dataset(presigned_url, file, "text/csv") do
      %{datasetLink: dataset_link}
      |> DatasetLinkFormSchema.changeset_from_form_data()
      |> send_dataset_link_status(socket)
      |> complete_validation(socket)
    else
      error ->
        socket.assigns.changeset
        |> send_error_interpreting_file(socket)
    end
  end

  def handle_event("file_upload", %{"file" => file, "fileName" => file_name, "fileType" => "application/json"}, socket) do
    dataset_id = socket.assigns.dataset_id
    dataset_link = "#{@bucket_path}#{dataset_id}/#{file_name}"

    with {:ok, presigned_url} <- presigned_url(dataset_id, file_name),
         {:ok, _} <- upload_sample_dataset(presigned_url, file, "application/json") do
      %{datasetLink: dataset_link}
      |> DatasetLinkFormSchema.changeset_from_form_data()
      |> send_dataset_link_status(socket)
      |> complete_validation(socket)
    else
      error ->
        socket.assigns.changeset
        |> send_error_interpreting_file(socket)
    end
  end

  def handle_event("file_upload", _, socket) do
    socket.assigns.changeset
    |> send_error_interpreting_file(socket)
  end

  def handle_event("file_upload_started", _, socket) do
    {:noreply, assign(socket, loading_schema: true)}
  end

  def handle_event("file_upload_cancelled", _, socket) do
    {:noreply, assign(socket, loading_schema: false)}
  end

  defp complete_validation(changeset, socket) do
    new_changeset = Map.put(changeset, :action, :update)
    send(socket.parent_pid, :form_update)

    {:noreply, assign(socket, changeset: new_changeset, loading_schema: false) |> update_validation_status()}
  end

  defp send_error_interpreting_file(changeset, socket, is_loading_schema \\ false) do
    new_changeset =
      changeset
      |> Map.put(:action, :update)
      |> Changeset.add_error(:datasetLink, "There was a problem interpreting this file")

    case is_loading_schema do
      true -> {:noreply, assign(socket, changeset: new_changeset)}
      _ -> {:noreply, assign(socket, changeset: new_changeset, loading_schema: false)}
    end
  end

  defp reset_changeset_errors(changeset) do
    Map.update!(changeset, :errors, fn errors -> Keyword.delete(errors, :datasetLink) end)
  end

  defp send_dataset_link_status(changeset, socket) do
    send(socket.parent_pid, {:update_dataset_link_status, changeset.valid?})
    changeset
  end

  defp parse_dataset_link(nil), do: "Upload file"

  defp parse_dataset_link(dataset_link) do
    regex_sample_file = ~r([^\/]+$)
    [file | _] = Regex.run(regex_sample_file, dataset_link)
    file
  end

  defp presigned_url(dataset_id, file_name) do
    ExAws.Config.new(:s3)
    |> ExAws.S3.presigned_url(:put, "#{hosted_bucket()}/#{@bucket_path}#{dataset_id}", file_name)
    |> case do
      {:ok, presigned_url} -> {:ok, presigned_url}
      {_, error} -> {:error, error}
    end
  end

  defp upload_sample_dataset(presigned_url, file_contents, content_type) do
    put(presigned_url, file_contents, headers: [{"content-type", content_type}])
    |> case do
      {:ok, response} -> {:ok, response}
      {_, error} -> {:error, error}
    end
  end
end
