defmodule AndiWeb.FormSection do
  @moduledoc """
  Macro defining common functions for LiveViews representing sections of the edit dataset page
  """

  defmacro __using__(opts) do
    schema_module = Keyword.fetch!(opts, :schema_module)

    quote do
      import Phoenix.LiveView

      def handle_event("save", _, socket) do
        changeset =
          socket.assigns.changeset
          |> Map.put(:action, :update)

        AndiWeb.Endpoint.broadcast_from(self(), "form-save", "save-all", %{dataset_id: socket.assigns.dataset_id})

        AndiWeb.Endpoint.broadcast_from(self(), "form-save", "form-save", %{
          form_changeset: changeset,
          dataset_id: socket.assigns.dataset_id
        })

        new_validation_status = get_new_validation_status(changeset)

        {:noreply, assign(socket, changeset: changeset, validation_status: new_validation_status)}
      end

      def handle_event("toggle-component-visibility", %{"component-expand" => next_component}, socket) do
        new_validation_status = get_new_validation_status(socket.assigns.changeset)

        AndiWeb.Endpoint.broadcast_from(self(), "toggle-visibility", "toggle-component-visibility", %{
          expand: next_component,
          dataset_id: socket.assigns.dataset_id
        })

        {:noreply, assign(socket, visibility: "collapsed", validation_status: new_validation_status)}
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
            %{topic: "form-save", event: "form-save", payload: %{dataset_id: dataset_id}},
            %{assigns: %{dataset_id: dataset_id}} = socket
          ) do
        new_validation_status =
          case socket.assigns.changeset.valid? do
            true -> "valid"
            false -> "invalid"
          end

        {:noreply, assign(socket, validation_status: new_validation_status)}
      end

      def handle_info(
            %{topic: "form-save", event: "save-all", payload: %{dataset_id: dataset_id}},
            %{assigns: %{dataset_id: dataset_id}} = socket
          ) do
        new_validation_status =
          case socket.assigns.changeset.valid? do
            true -> "valid"
            false -> "invalid"
          end

        {:ok, andi_dataset} = Andi.InputSchemas.Datasets.save_form_changeset(socket.assigns.dataset_id, socket.assigns.changeset)

        new_changeset =
          apply(unquote(schema_module), :changeset_from_andi_dataset, [andi_dataset])
          |> Map.put(:action, :update)

        {:noreply, assign(socket, changeset: new_changeset, validation_status: new_validation_status)}
      end

      def handle_info(
            %{topic: "form-save", event: "save-all", payload: %{ingestion_id: ingestion_id}},
            %{assigns: %{ingestion_id: ingestion_id}} = socket
          ) do
        new_validation_status =
          case socket.assigns.changeset.valid? do
            true -> "valid"
            false -> "invalid"
          end

        # Todo: Rearchitect how concurrent events are handled and remove these sleeps from draft-save and publish of datasets and ingestions
        # This sleep is needed because other save events are executing. save_form_changeset will load the ingestion from the database.
        Process.sleep(1_000)

        {:ok, andi_ingestion} = Andi.InputSchemas.Ingestions.save_form_changeset(socket.assigns.ingestion_id, socket.assigns.changeset)

        new_changeset =
          apply(unquote(schema_module), :changeset_from_andi_ingestion, [andi_ingestion])
          |> Map.put(:action, :update)

        {:noreply, assign(socket, changeset: new_changeset, validation_status: new_validation_status)}
      end

      def handle_info(%{topic: "form-save"}, socket) do
        {:noreply, socket}
      end

      def handle_info(%{topic: "toggle-component-visibility"}, socket) do
        {:noreply, socket}
      end

      def update_validation_status(%{assigns: %{validation_status: validation_status, visibility: visibility}} = socket)
          when validation_status in ["valid", "invalid"] or visibility == "collapsed" do
        assign(socket, validation_status: get_new_validation_status(socket.assigns.changeset))
      end

      def update_validation_status(%{assigns: %{visibility: visibility}} = socket), do: assign(socket, validation_status: visibility)

      def handle_event("cancel-edit", _, socket) do
        send(socket.parent_pid, :cancel_edit)
        {:noreply, socket}
      end

      defp get_new_validation_status(changeset) do
        case changeset.valid? do
          true -> "valid"
          false -> "invalid"
        end
      end
    end
  end
end
