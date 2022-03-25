defmodule AndiWeb.IngestionLiveView.ExtractSteps.ExtractStepForm do
  @moduledoc """
  LiveComponent for editing dataset extract steps
  """
  use Phoenix.LiveView
  import Phoenix.HTML.Form
  require Logger

  alias Andi.InputSchemas.Datasets.ExtractStep
  alias AndiWeb.Views.Options
  alias Andi.InputSchemas.ExtractSteps
  alias AndiWeb.IngestionLiveView.ExtractSteps.ExtractDateStepForm
  alias AndiWeb.IngestionLiveView.ExtractSteps.ExtractHttpStepForm
  # TODO: Use IngestionLiveView Versions
  alias AndiWeb.ExtractSteps.ExtractSecretStepForm
  alias AndiWeb.ExtractSteps.ExtractAuthStepForm
  alias AndiWeb.ExtractSteps.ExtractS3StepForm
  alias AndiWeb.ExtractSteps.ExtractPlaceholderStepForm
  alias Andi.InputSchemas.InputConverter
  alias Andi.InputSchemas.StructTools
  alias AndiWeb.Helpers.ExtractStepHelpers

  def mount(_params, %{"ingestion" => ingestion}, socket) do
    extract_steps = Map.get(ingestion, :extractSteps)
    AndiWeb.Endpoint.subscribe("form-save")

    extract_step_changesets =
      Enum.reduce(extract_steps, %{}, fn extract_step, acc ->
        changeset = ExtractStep.form_changeset_from_andi_extract_step(extract_step)
        Map.put(acc, extract_step.id, changeset)
      end)

    {:ok,
     assign(socket,
       extract_steps: extract_steps,
       extract_step_changesets: extract_step_changesets,
       visibility: "collapsed",
       validation_status: "collapsed",
       ingestion_id: ingestion.id,
       new_step_type: ""
     )}
  end

  # def mount(_params, %{"dataset" => dataset}, socket) do
  #   AndiWeb.Endpoint.subscribe("toggle-visibility")
  #   AndiWeb.Endpoint.subscribe("form-save")

  #   extract_steps = get_in(dataset, [:technical, :extractSteps])

  #   extract_step_changesets =
  #     Enum.reduce(extract_steps, %{}, fn extract_step, acc ->
  #       changeset = ExtractStep.form_changeset_from_andi_extract_step(extract_step)
  #       Map.put(acc, extract_step.id, changeset)
  #     end)

  #   {:ok,
  #    assign(socket,
  #      extract_steps: extract_steps,
  #      extract_step_changesets: extract_step_changesets,
  #      testing: false,
  #      visibility: "collapsed",
  #      validation_status: "collapsed",
  #      validation_map: %{},
  #      dataset_id: dataset.id,
  #      technical_id: dataset.technical.id,
  #      new_step_type: "",
  #      dataset_link: dataset.datasetLink
  #    )}
  # end

  def render(assigns) do
    action =
      case assigns.visibility do
        "collapsed" -> "EDIT"
        "expanded" -> "MINIMIZE"
      end

    ~L"""
    <div id="extract-step-form" class="form-component">
      <div class="component-header" phx-click="toggle-component-visibility" phx-value-component="extract_form">
        <div class="section-number">
          <h3 class="component-number component-number--<%= @validation_status %>">1</h3>
          <div class="component-number-status--<%= @validation_status %>"></div>
        </div>
        <div class="component-title full-width">
          <h2 class="component-title-text component-title-text--<%= @visibility %> ">Configure Ingest Steps</h2>
          <div class="component-title-action">
            <div class="component-title-action-text--<%= @visibility %>"><%= action %></div>
            <div class="component-title-icon--<%= @visibility %>"></div>
          </div>
        </div>
      </div>

      <div class="form-section">
        <div class="component-edit-section--<%= @visibility %>">

          <div class="add-step">
            <%= select(:form, :step_type, get_extract_step_types(), phx_blur: "update_new_step_type", selected: @new_step_type, id: "extract_step_type", class: "extract-step-form__step-type select") %>
            <button class="btn" type="button" phx-click="add-extract-step">Add Step</button>
          </div>

          <div class="extract-steps__error-message"><%= extract_steps_error_message(@extract_steps) %></div>

          <%= for extract_step <- @extract_steps do %>
            <% component_module_to_render = render_extract_step_form(extract_step) %>
            <% step_changeset = Map.get(@extract_step_changesets, extract_step.id) %>

            <hr>
            <%= live_component(@socket, component_module_to_render, id: extract_step.id, extract_step: extract_step, changeset: step_changeset) %>
          <% end %>

        </div>
      </div>
    </div>
    """
  end

  # def render(assigns) do
  #   action =
  #     case assigns.visibility do
  #       "collapsed" -> "EDIT"
  #       "expanded" -> "MINIMIZE"
  #     end

  #   ~L"""
  #     <div id="extract-step-form" class="form-component">
  #       <div class="component-header" phx-click="toggle-component-visibility" phx-value-component="extract_form">
  #         <div class="section-number">
  #           <h3 class="component-number component-number--<%= @validation_status %>">3</h3>
  #           <div class="component-number-status--<%= @validation_status %>"></div>
  #         </div>
  #         <div class="component-title full-width">
  #           <h2 class="component-title-text component-title-text--<%= @visibility %> ">Configure Ingest Steps</h2>
  #           <div class="component-title-action">
  #             <div class="component-title-action-text--<%= @visibility %>"><%= action %></div>
  #             <div class="component-title-icon--<%= @visibility %>"></div>
  #           </div>
  #         </div>
  #       </div>

  #       <div class="form-section">
  #         <div class="component-edit-section--<%= @visibility %>">

  # TODO: What is dataset_link. should this just be axed for ingestions.
  #           <%= if @dataset_link != nil do %>
  #             <div class="download_dataset_sample">
  #               <h4>Dataset Link:</h4>
  #               <a id="download_dataset_sample_link" target="_blank" href="/datasets/<%= @dataset_id %>/sample">
  #                 <%= get_file_name_from_dataset_link(@dataset_link) %>
  #               </a>
  #             </div>
  #           <% end %>

  #           <div class="add-step">
  #             <%= select(:form, :step_type, get_extract_step_types(), phx_blur: "update_new_step_type", selected: @new_step_type, id: "extract_step_type", class: "extract-step-form__step-type select") %>
  #             <button class="btn" type="button" phx-click="add-extract-step">Add Step</button>
  #           </div>

  #           <div class="extract-steps__error-message"><%= extract_steps_error_message(@extract_steps) %></div>

  #           <%= for extract_step <- @extract_steps do %>
  #             <% component_module_to_render = render_extract_step_form(extract_step) %>
  #             <% step_changeset = Map.get(@extract_step_changesets, extract_step.id) %>

  #             <hr>
  #             <%= live_component(@socket, component_module_to_render, id: extract_step.id, extract_step: extract_step, technical_id: @technical_id, dataset_id: @dataset_id, changeset: step_changeset) %>
  #           <% end %>

  #           <div class="edit-button-group form-grid">
  #             <a href="#data-dictionary-form" id="back-button" class="btn btn--back btn--large" phx-click="toggle-component-visibility" phx-value-component-expand="data_dictionary_form">Back</a>

  #             <a href="#finalize_form" id="next-button" class="btn btn--next btn--large btn--action" phx-click="toggle-component-visibility" phx-value-component-expand="finalize_form">Next</a>
  #           </div>
  #         </div>
  #       </div>
  #     </div>
  #   """
  # end

  # def handle_event("toggle-component-visibility", %{"component-expand" => next_component}, socket) do
  #   new_validation_status = get_new_validation_status(socket.assigns.extract_step_changesets, socket.assigns.extract_steps)

  #   AndiWeb.Endpoint.broadcast_from(self(), "toggle-visibility", "toggle-component-visibility", %{
  #     expand: next_component,
  #     dataset_id: socket.assigns.dataset_id
  #   })

  #   {:noreply, assign(socket, visibility: "collapsed", validation_status: new_validation_status)}
  # end

  # def handle_event("toggle-component-visibility", _, socket) do
  #   current_visibility = Map.get(socket.assigns, :visibility)

  #   new_visibility =
  #     case current_visibility do
  #       "expanded" -> "collapsed"
  #       "collapsed" -> "expanded"
  #     end

  #   {:noreply, assign(socket, visibility: new_visibility) |> update_validation_status()}
  # end

  def handle_event(
        "save",
        _,
        %{assigns: %{extract_step_changesets: extract_step_changesets}} = socket
      ) do
    save_step_changesets(extract_step_changesets)

    AndiWeb.Endpoint.broadcast_from(self(), "form-save", "save-all", %{
      ingestion_id: socket.assigns.ingestion_id
    })

    new_validation_status = get_new_validation_status(extract_step_changesets, socket.assigns.extract_steps)

    send(socket.parent_pid, {:update_save_message, new_validation_status})

    {:noreply, assign(socket, validation_status: new_validation_status)}
  end

  def handle_event("update_new_step_type", %{"value" => value}, socket) do
    {:noreply, assign(socket, new_step_type: value)}
  end

  def handle_event("add-extract-step", _, %{assigns: %{new_step_type: ""}} = socket) do
    {:noreply, socket}
  end

  def handle_event("add-extract-step", _, socket) do
    step_type = socket.assigns.new_step_type
    ingestion_id = socket.assigns.ingestion_id
    new_step_changes = %{type: step_type, context: %{}, ingestion_id: ingestion_id}

    {:ok, new_extract_step} = ExtractSteps.create(new_step_changes)
    {:ok, _} = ExtractSteps.update(new_extract_step)

    new_extract_step_changeset = ExtractStep.form_changeset_from_andi_extract_step(new_extract_step)

    updated_changeset_map =
      Map.put(
        socket.assigns.extract_step_changesets,
        new_extract_step.id,
        new_extract_step_changeset
      )

    all_steps_for_ingestion = ExtractSteps.all_for_ingestion(ingestion_id) |> StructTools.sort_if_sequenced()

    {:noreply,
     assign(socket,
       extract_steps: all_steps_for_ingestion,
       extract_step_changesets: updated_changeset_map
     )
     |> update_validation_status()}
  end

  def handle_event("move-extract-step", %{"id" => extract_step_id, "move-index" => move_index_string}, socket) do
    move_index = String.to_integer(move_index_string)
    extract_step_index = Enum.find_index(socket.assigns.extract_steps, fn extract_step -> extract_step.id == extract_step_id end)
    target_index = extract_step_index + move_index

    case target_index >= 0 && target_index < Enum.count(socket.assigns.extract_steps) do
      true -> move_extract_step(socket, extract_step_index, target_index)
      false -> {:noreply, socket}
    end
  end

  def handle_event("remove-extract-step", %{"id" => extract_step_id}, %{assigns: %{ingestion_id: ingestion_id}} = socket) do
    ExtractSteps.delete(extract_step_id)
    updated_changeset_map = Map.delete(socket.assigns.extract_step_changesets, extract_step_id)
    all_steps_for_ingestion = ExtractSteps.all_for_ingestion(ingestion_id) |> StructTools.sort_if_sequenced()

    {:noreply,
     assign(socket, extract_steps: all_steps_for_ingestion, extract_step_changesets: updated_changeset_map) |> update_validation_status()}
  end

  def handle_event("toggle-component-visibility", _, socket) do
    current_visibility = Map.get(socket.assigns, :visibility)

    new_visibility =
      case current_visibility do
        "expanded" -> "collapsed"
        "collapsed" -> "expanded"
      end

    {:noreply, assign(socket, visibility: new_visibility) |> update_validation_status()}
  end

  def handle_info(
        %{topic: "form-save", event: "save-all", payload: %{ingestion_id: ingestion_id}},
        %{
          assigns: %{
            extract_step_changesets: extract_step_changesets,
            ingestion_id: ingestion_id,
            extract_steps: extract_steps
          }
        } = socket
      ) do
    save_step_changesets(extract_step_changesets)

    {:noreply,
     assign(socket,
       validation_status: get_new_validation_status(extract_step_changesets, extract_steps)
     )}
  end

  def handle_info(%{topic: "form-save"}, socket) do
    {:noreply, socket}
  end

  # def handle_info(%{topic: "toggle-component-visibility"}, socket) do
  #   {:noreply, socket}
  # end

  def handle_info({:step_update, step_id, new_changeset}, socket) do
    updated_extract_step_changesets =
      socket.assigns.extract_step_changesets
      |> Map.put(step_id, new_changeset)

    {:noreply,
     assign(socket, extract_step_changesets: updated_extract_step_changesets)
     |> update_validation_status()}
  end

  # def handle_info(
  #       {:validation_status, {step_id, status}},
  #       %{assigns: %{validation_map: validation_map}} = socket
  #     ) do
  #   new_map = Map.put(validation_map, step_id, status)

  #   new_status =
  #     case Enum.any?(new_map, fn {_, status} -> status == "invalid" end) do
  #       false -> "valid"
  #       true -> "invalid"
  #     end

  #   {:noreply, assign(socket, validation_map: new_map, validation_status: new_status)}
  # end

  # # This handle_info takes care of all exceptions in a generic way.
  # # Expected errors should be handled in specific handlers.
  # # Flags should be reset here.
  # def handle_info({:EXIT, _pid, {_error, _stacktrace}}, socket) do
  #   send(socket.parent_pid, :page_error)
  #   {:noreply, assign(socket, page_error: true, testing: false, save_success: false)}
  # end

  # def handle_info(message, socket) do
  #   Logger.debug(inspect(message))
  #   {:noreply, socket}
  # end

  defp get_file_name_from_dataset_link(dataset_link) do
    dataset_link
    |> String.split("/")
    |> List.last()
  end

  defp move_extract_step(socket, extract_step_index, target_index) do
    updated_extract_steps =
      socket.assigns.extract_steps
      |> ExtractStepHelpers.move_element(extract_step_index, target_index)
      |> Enum.with_index()
      |> Enum.map(fn {extract_step, index} ->
        {:ok, updated_step} = ExtractSteps.update(extract_step, %{sequence: index})
        updated_step
      end)

    {:noreply, assign(socket, extract_steps: updated_extract_steps)}
  end

  defp save_step_changesets(extract_step_changesets) do
    Enum.each(extract_step_changesets, fn {id, changeset} ->
      changes = InputConverter.form_changes_from_changeset(changeset)

      id
      |> ExtractSteps.get()
      |> Map.put(:context, changes)
      |> ExtractSteps.update()
    end)
  end

  defp render_extract_step_form(%{type: "http"}), do: ExtractHttpStepForm

  defp render_extract_step_form(%{type: "date"}), do: ExtractDateStepForm

  defp render_extract_step_form(%{type: "secret"}), do: ExtractSecretStepForm

  defp render_extract_step_form(%{type: "auth"}), do: ExtractAuthStepForm

  defp render_extract_step_form(%{type: "s3"}), do: ExtractS3StepForm

  defp render_extract_step_form(_), do: ExtractPlaceholderStepForm

  defp get_extract_step_types(), do: map_to_dropdown_options(Options.extract_step_type())

  defp map_to_dropdown_options(options) do
    Enum.map(options, fn {actual_value, description} ->
      [key: description, value: actual_value]
    end)
  end

  defp update_validation_status(
         %{
           assigns: %{
             validation_status: validation_status,
             visibility: visibility,
             extract_steps: extract_steps
           }
         } = socket
       )
       when validation_status in ["valid", "invalid"] or visibility == "collapsed" do
    assign(socket,
      validation_status: get_new_validation_status(socket.assigns.extract_step_changesets, extract_steps)
    )
  end

  defp update_validation_status(%{assigns: %{visibility: visibility}} = socket),
    do: assign(socket, validation_status: visibility)

  defp get_new_validation_status(step_changesets, []) when step_changesets == %{}, do: "invalid"

  defp get_new_validation_status(step_changesets, extract_steps) do
    case ExtractStepHelpers.ends_with_http_or_s3_step?(extract_steps) and
           extract_step_changesets_valid?(step_changesets) do
      true -> "valid"
      false -> "invalid"
    end
  end

  defp extract_steps_error_message(extract_steps) when extract_steps in [nil, []],
    do: "Extract steps cannot be empty"

  defp extract_steps_error_message(extract_steps) do
    case ExtractStepHelpers.ends_with_http_or_s3_step?(extract_steps) do
      false -> "Extract steps must end with a HTTP or S3 step"
      true -> nil
    end
  end

  defp extract_step_changesets_valid?(step_changesets) do
    Enum.all?(step_changesets, fn
      {_, %{changes: _} = changeset} -> changeset.valid?
      _ -> true
    end)
  end
end
