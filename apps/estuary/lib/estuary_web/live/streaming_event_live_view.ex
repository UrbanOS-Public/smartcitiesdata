defmodule EstuaryWeb.StreamingEventLiveView do
  use Phoenix.LiveView
  alias EstuaryWeb.Router.Helpers, as: Routes
  alias EstuaryWeb.EventLiveView.StreamingTable

  @updated_event_stream "updated_event_stream"

  def render(assigns) do
    ~L"""
    <div class="events-index">
      <h1 class="events-index__title">All Events</h1>
      <%= live_component(@socket, StreamingTable, create_ts: :events_table, events: @events) %>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    EstuaryWeb.Endpoint.subscribe(@updated_event_stream)
    {:ok,
     assign(socket, events: nil, search_text: nil, order: {"create_ts", "asc"}, params: %{})}
  end

  def handle_info(
        %{topic: @updated_event_stream, payload: %{"create_ts" => create_ts}},
        socket
      ) do
    updated_events = update_event_stream(create_ts, socket.assigns.events)
    updated_state = assign(socket, :events, updated_events)

    {:noreply, updated_state}
  end

  # def handle_params(params, _uri, socket) do
  #   order_by = Map.get(params, "order-by", "data_title")
  #   order_dir = Map.get(params, "order-dir", "asc")
  #   search_text = Map.get(params, "search", "")

  #   view_models =
  #     filter_on_search_change(search_text, socket)
  #     |> sort_by_dir(order_by, order_dir)

  #   {:noreply,
  #    assign(socket,
  #      search_text: search_text,
  #      events: view_models,
  #      order: %{order_by => order_dir},
  #      params: params
  #    )}
  # end

  # def handle_event("search", %{"search-value" => value}, socket) do
  #   search_params = Map.merge(socket.assigns.params, %{"search" => value})
  #   {:noreply, push_patch(socket, to: Routes.live_path(socket, __MODULE__, search_params))}
  # end

  # def handle_event("order-by", %{"field" => field}, socket) do
  #   order_dir =
  #     case socket.assigns.order do
  #       %{^field => "asc"} -> "desc"
  #       _ -> "asc"
  #     end

  #   params = Map.merge(socket.assigns.params, %{"order-by" => field, "order-dir" => order_dir})
  #   {:noreply, push_patch(socket, to: Routes.live_path(socket, __MODULE__, params))}
  # end

  # defp filter_on_search_change(search_value, socket) do
  #   case search_value == socket.assigns.search_text do
  #     false ->
  #       Andi.DatasetCache.get_all()
  #       |> ignore_incomplete_models
  #       |> filter_models(search_value)
  #       |> Enum.map(&to_view_model/1)

  #     _ ->
  #       socket.assigns.events
  #   end
  # end

  # defp ignore_incomplete_models(models) do
  #   Enum.reject(models, fn model -> is_nil(model["event"]) end)
  # end

  # defp filter_models(models, ""), do: models

  # defp filter_models(models, value) do
  #   Enum.filter(models, fn model ->
  #     search_contains?(model["event"].business.orgTitle, value) ||
  #       search_contains?(model["event"].business.dataTitle, value)
  #   end)
  # end

  # defp search_contains?(str, search_str) do
  #   String.downcase(str) =~ String.downcase(search_str)
  # end

  # defp sort_by_dir(models, order_by, order_dir) do
  #   case order_dir do
  #     "asc" -> Enum.sort_by(models, fn model -> Map.get(model, order_by) end)
  #     "desc" -> Enum.sort_by(models, fn model -> Map.get(model, order_by) end, &>=/2)
  #     _ -> models
  #   end
  # end

  defp update_event_stream(create_ts, events) do
    exisiting_index = Enum.find_index(events, fn event -> create_ts == event["create_ts"] end)

    case is_nil(exisiting_index) do
      true ->
        events

      _ ->
        updated_event =
          events
          |> Enum.at(exisiting_index)
          |> Map.put("create_ts", create_ts)

        List.replace_at(events, exisiting_index, updated_event)
    end
  end

  # defp to_view_model(model) do
  #   %{
  #     "id" => model["id"],
  #     "org_title" => model["event"].business.orgTitle,
  #     "data_title" => model["event"].business.dataTitle,
  #     "created_time" => Map.get(model, "created_time")
  #   }
  # end
end
