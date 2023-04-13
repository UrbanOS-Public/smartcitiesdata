defmodule AndiWeb.IngestionLiveView.ExtractSteps.ExtractStepForm do
  @moduledoc """
  LiveComponent for editing dataset extract steps
  """
  use Phoenix.LiveComponent
  import Phoenix.HTML.Form

  alias AndiWeb.Views.Options
  alias Andi.InputSchemas.StructTools
  alias Andi.InputSchemas.Ingestions.ExtractStep
  alias Ecto.Changeset
  alias AndiWeb.ExtractSteps.ExtractDateStepForm
  alias AndiWeb.ExtractSteps.ExtractHttpStepForm
  alias AndiWeb.ExtractSteps.ExtractSecretStepForm
  alias AndiWeb.ExtractSteps.ExtractAuthStepForm
  alias AndiWeb.ExtractSteps.ExtractS3StepForm
  alias AndiWeb.ExtractSteps.ExtractPlaceholderStepForm
  alias AndiWeb.ExtractSteps.ExtractStepHeader
  alias Andi.UrlBuilder

  def component_id() do
    :extract_step_form_editor
  end

  def component_step(), do: "Configure Ingest Steps"

  def mount(socket) do
    {
      :ok,
      assign(socket, visible?: false)
    }
  end

  def render(assigns) do
    visible = if assigns.visible?, do: "expanded", else: "collapsed"
    validation_status = get_validation_status(assigns.extract_step_changesets, assigns.extract_step_errors)

    ~L"""
    <div id="extract-step-form" class="form-component form-beginning">
      <div>
        <%= live_component(
          AndiWeb.FormCollapsibleHeader,
          order: @order,
          visible?: @visible?,
          validation_status: validation_status,
          step: component_step(),
          id: AndiWeb.FormCollapsibleHeader.component_id(component_step()),
          visibility_change_callback: &change_visibility/1)
        %>
      </div>

      <div id="extract-step-form-section" class="form-section">
        <div class="component-edit-section--<%= visible %>">
          <div class="add-step">
            <%= f = form_for :form, "#", [ as: :form_data, phx_submit: :add_extract_step, phx_target: @myself, id: :extract_addition_form ] %>
              <%= select(f, :step_type, get_extract_step_types(), id: "extract_step_type", class: "extract-step-form__step-type select", aria_label: "Select New Step Type") %>
              <button class="btn btn--primary-outline" type="submit">Add Step</button>
              <div class="extract-steps__error-message"><%= @extract_step_errors %></div>
            </form>
          </div>

          <%= for extract_step_changeset <- sort_by_sequence(@extract_step_changesets) do %>
            <% {_, extract_step_changeset_id} = Changeset.fetch_field(extract_step_changeset, :id) %>
            <hr>
            <div id="step-<%= extract_step_changeset_id %>" class="extract-step-container extract-secret-step-form">
              <% {form_module, step_name} = inspect_module(Changeset.fetch_field(extract_step_changeset, :type)) %>
              <% changeset = ExtractStep.create_step_changeset_from_generic_step_changeset(extract_step_changeset) %>

              <%= live_component(ExtractStepHeader, step_name: step_name, step_id: extract_step_changeset_id, parent_id: @myself) %>
              <%= live_component(form_module, id: extract_step_changeset_id, changeset: changeset) %>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  defp get_extract_step_types(), do: map_to_dropdown_options(Options.extract_step_type())

  defp map_to_dropdown_options(options) do
    Enum.map(options, fn {actual_value, description} ->
      [key: description, value: actual_value]
    end)
  end

  def handle_event("add_extract_step", assigns, socket) do
    step_type = Map.get(Map.get(assigns, "form"), "step_type")
    ingestion_id = socket.assigns.ingestion_id
    sequence = length(socket.assigns.extract_step_changesets)

    new_step_changes = %{type: step_type, context: %{}, ingestion_id: ingestion_id, sequence: sequence}

    new_changeset = ExtractStep.changeset(%ExtractStep{}, new_step_changes)

    new_extract_step_changesets = [new_changeset | socket.assigns.extract_step_changesets] |> sort_by_sequence()

    send(self(), {:update_all_extract_steps, new_extract_step_changesets})
    {:noreply, socket}
  end

  def handle_event(
        "move-extract-step",
        %{"id" => extract_step_id, "move-index" => move_index_string},
        socket
      ) do
    move_index = String.to_integer(move_index_string)

    changeset_to_update =
      Enum.find(socket.assigns.extract_step_changesets, fn changeset ->
        changeset_id =
          case Changeset.fetch_field(changeset, :id) do
            {_, id} -> id
            :error -> nil
          end

        changeset_id == extract_step_id
      end)

    changeset_sequence =
      case Changeset.fetch_field(changeset_to_update, :sequence) do
        {_, sequence} -> sequence
        :error -> 0
      end

    new_index = changeset_sequence + move_index

    if new_index >= 0 and new_index < length(socket.assigns.extract_step_changesets) do
      sorted_changesets =
        socket.assigns.extract_step_changesets
        |> sort_by_sequence()

      {extract_step_to_move, remaining_list} = List.pop_at(sorted_changesets, changeset_sequence)

      updated_extract_step_changesets =
        List.insert_at(remaining_list, new_index, extract_step_to_move)
        |> Enum.with_index()
        |> Enum.map(fn {changeset, index} ->
          ExtractStep.changeset(changeset, %{sequence: index})
        end)

      send(self(), {:update_all_extract_steps, updated_extract_step_changesets})
    end

    {:noreply, socket}
  end

  def handle_event("remove-extract-step", %{"id" => extract_step_id}, socket) do
    element_to_delete =
      Enum.find(socket.assigns.extract_step_changesets, fn changeset ->
        changeset_id =
          case Changeset.fetch_field(changeset, :id) do
            {_, id} -> id
            :error -> nil
          end

        changeset_id == extract_step_id
      end)

    new_extract_step_changesets =
      List.delete(socket.assigns.extract_step_changesets, element_to_delete)
      |> sort_by_sequence()
      |> Enum.with_index()
      |> Enum.map(fn {changeset, index} ->
        Changeset.put_change(changeset, :sequence, index)
      end)

    send(self(), {:update_all_extract_steps, new_extract_step_changesets})
    {:noreply, socket}
  end

  def handle_event(event, payload, socket) do
    IO.inspect("Unhandled Event in module #{__MODULE__}")
    IO.inspect(event, label: "Event")
    IO.inspect(payload, label: "Payload")
    IO.inspect(socket, label: "Socket")

    {:noreply, socket}
  end

  def handle_event(event, socket) do
    IO.inspect("Event: #{event}, socket: #{socket}",
      label: 'Unhandled Event in module #{__MODULE__}'
    )

    {:noreply, socket}
  end

  def update_extract_step(changeset, step_id) do
    send_update(__MODULE__,
      id: component_id(),
      updated_extract_step_changeset: changeset,
      step_id: step_id
    )
  end

  def update_test_url(step_id) do
    send_update(__MODULE__,
      id: component_id(),
      step_id: step_id
    )
  end

  def change_visibility(updated_visibility) do
    send_update(__MODULE__,
      id: component_id(),
      visible?: updated_visibility
    )
  end

  def update(%{updated_extract_step_changeset: changeset, step_id: step_id}, socket) do
    changes = %{context: StructTools.to_map(Changeset.apply_changes(changeset))}

    updated_extract_step_changesets =
      Enum.map(socket.assigns.extract_step_changesets, fn changeset ->
        changeset_id =
          case Changeset.fetch_field(changeset, :id) do
            {_, id} -> id
            :error -> nil
          end

        case changeset_id == step_id do
          true -> ExtractStep.changeset(changeset, changes)
          false -> changeset
        end
      end)

    send(self(), {:update_all_extract_steps, updated_extract_step_changesets})
    {:ok, socket}
  end

  def update(%{step_id: step_id}, socket) do
    compiled_steps =
      Enum.reduce(socket.assigns.extract_step_changesets, %{}, fn extract_step, acc ->
        extract_step
        |> Changeset.apply_changes()
        |> AtomicMap.convert(underscore: true)
        |> process_extract_step(socket.assigns.ingestion_id, acc)
      end)

    AndiWeb.ExtractSteps.ExtractHttpStepForm.update_test_url(compiled_steps, step_id)
    {:ok, socket}
  end

  def update(assigns, socket) do
    {:ok, assign(socket, assigns)}
  end

  defp inspect_module({_, "http"}), do: {ExtractHttpStepForm, "HTTP"}

  defp inspect_module({_, "date"}), do: {ExtractDateStepForm, "Date"}

  defp inspect_module({_, "secret"}), do: {ExtractSecretStepForm, "Secret"}

  defp inspect_module({_, "auth"}), do: {ExtractAuthStepForm, "Auth"}

  defp inspect_module({_, "s3"}), do: {ExtractS3StepForm, "S3"}

  defp inspect_module(_), do: {ExtractPlaceholderStepForm, "Placeholder"}

  defp sort_by_sequence(changeset_list) do
    Enum.sort_by(changeset_list, &Changeset.fetch_field!(&1, :sequence))
  end

  defp process_extract_step(%{type: "date"} = step, _ingestion_id, bindings) do
    date =
      case step.context.delta_time_unit do
        nil ->
          Timex.now()

        _ ->
          unit = String.to_atom(step.context.delta_time_unit)
          Timex.shift(Timex.now(), [{unit, step.context.delta_time_value}])
      end

    formatted_date = Timex.format!(date, step.context.format)
    Map.put(bindings, step.context.destination |> String.to_atom(), formatted_date)
  end

  defp process_extract_step(%{type: "secret"} = step, _ingestion_id, bindings) do
    case Andi.SecretService.retrieve_ingestion_credentials(step.context.key) do
      {:ok, cred} -> Map.put(bindings, step.context.destination |> String.to_atom(), Map.get(cred, step.context.sub_key))
      _ -> bindings
    end
  end

  defp process_extract_step(%{type: "auth"} = step, ingestion_id, bindings) do
    {body, headers} = evaluate_body_and_headers(step, bindings)

    url = UrlBuilder.build_safe_url_path(step.context.url, bindings)

    response =
      Andi.AuthRetriever.authorize(ingestion_id, url, body, step.context.encode_method, headers)
      |> Jason.decode!()
      |> get_in(step.context.path)

    Map.put(bindings, step.context.destination |> String.to_atom(), response)
  end

  defp process_extract_step(_step, _ingestion_id, bindings), do: bindings

  defp evaluate_body_and_headers(step, bindings) do
    body =
      case Map.fetch(step.context, :body) do
        {:ok, body} -> process_body(body, bindings)
        _ -> ""
      end

    headers = UrlBuilder.safe_evaluate_parameters(step.context.headers, bindings)

    {body, headers}
  end

  defp process_body(body, _assigns) when body in ["", nil], do: ""

  defp process_body(body, assigns) do
    body
    |> UrlBuilder.safe_evaluate_parameters(assigns)
    |> Enum.into(%{})
    |> Jason.encode!()
  end

  defp get_validation_status(_extract_step_changesets, extract_step_errors) when extract_step_errors != "", do: "invalid"

  defp get_validation_status(extract_step_changesets, _extract_step_errors) do
    case Enum.all?(extract_step_changesets, fn changeset ->
           step_changeset = ExtractStep.create_step_changeset_from_generic_step_changeset(changeset)
           step_changeset.valid?
         end) do
      true -> "valid"
      false -> "invalid"
    end
  end
end
