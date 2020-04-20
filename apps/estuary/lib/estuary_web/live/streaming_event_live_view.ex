defmodule EstuaryWeb.StreamingEventLiveView do
  use Phoenix.LiveView
  alias EstuaryWeb.EventLiveView.StreamingTable

  @updated_event_stream "updated_event_stream"

  def render(assigns) do
    ~L"""
    <div class="events-index">
      <h1 class="events-index__title">All Events</h1>
      <%= live_component(@socket, StreamingTable, id: :events_table, events: @events, order: @order) %>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    EstuaryWeb.Endpoint.subscribe(@updated_event_stream)
    {:ok, assign(socket, events: nil, order: {"create_ts", "asc"}, params: %{})}
  end

  def handle_info(
        %{topic: @updated_event_stream, payload: %{"author" => author, "create_ts" => create_ts, "data" => data, "type" => type}},
        socket
      ) do
    updated_events = update_event_stream(create_ts, socket.assigns.events)
    updated_state = assign(socket, :events, updated_events)

    {:noreply, updated_state}
  end

  def handle_params(params, _uri, socket) do
    order_by = Map.get(params, "order-by", "create_ts")
    order_dir = Map.get(params, "order-dir", "asc")
   
     view_models = socket.assigns.events

    {:noreply, assign(socket, events: view_models, order: %{order_by => order_dir}, params: params)}
  end

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

  defp to_view_model(model) do
    IO.inspect(model, label: "dddddddd")
    %{
      "author" => model["author"],
      "create_ts" => model["create_ts"],
      "data" => model["data"],
      "type" => model["type"]
    }
  end
end
