defmodule AndiWeb.IngestionFormSection do
  @moduledoc """
  Macro defining common functions for LiveViews representing sections of the edit dataset page
  """

  defmacro __using__(_) do

    quote do
      import Phoenix.LiveView

      def handle_event("toggle-component-visibility", _, socket) do
        current_visibility = Map.get(socket.assigns, :visibility)

        new_visibility =
          case current_visibility do
            "expanded" -> "collapsed"
            "collapsed" -> "expanded"
          end

        {:noreply, assign(socket, visibility: new_visibility) |> update_validation_status()}
      end

      def handle_info(%{topic: "toggle-component-visibility"}, socket) do
        {:noreply, socket}
      end

      def update_validation_status(%{assigns: %{validation_status: validation_status, visibility: visibility, changeset: changeset}} = socket)
          when validation_status in ["valid", "invalid"] or visibility == "collapsed" do
        assign(socket, validation_status: get_new_validation_status(changeset))
      end

      def update_validation_status(%{assigns: %{visibility: visibility}} = socket), do: assign(socket, validation_status: visibility)

      defp get_new_validation_status(changeset) when is_list(changeset) == false do
        case changeset.valid? do
          true -> "valid"
          false -> "invalid"
        end
      end
    end
  end
end
