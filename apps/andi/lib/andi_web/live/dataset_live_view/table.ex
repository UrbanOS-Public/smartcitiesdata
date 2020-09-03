defmodule AndiWeb.DatasetLiveView.Table do
  @moduledoc """
    LiveComponent for dataset table
  """

  use Phoenix.LiveComponent
  import Phoenix.HTML
  alias Phoenix.HTML.Link
  alias Andi.InputSchemas.Datasets

  def render(assigns) do
    ~L"""
    <div id="<%= @id %>" class="datasets-index__table">
      <table class="datasets-table">
      <thead>
        <th class="datasets-table__th datasets-table__cell datasets-table__th--sortable datasets-table__th--<%= Map.get(@order, "ingested_time", "unsorted") %>" phx-click="order-by" phx-value-field="ingested_time">Status</th>
        <th class="datasets-table__th datasets-table__cell datasets-table__th--sortable datasets-table__th--<%= Map.get(@order, "data_title", "unsorted") %>" phx-click="order-by" phx-value-field="data_title">Dataset Name </th>
        <th class="datasets-table__th datasets-table__cell datasets-table__th--sortable datasets-table__th--<%= Map.get(@order, "org_title", "unsorted") %>" phx-click="order-by" phx-value-field="org_title">Organization </th>
        <th class="datasets-table__th datasets-table__cell">Actions</th>
        </thead>

        <%= if @datasets == [] do %>
          <tr><td class="datasets-table__cell" colspan="100%">No Datasets Found!</td></tr>
        <% else %>
          <%= for dataset <- @datasets do %>
            <% ingest_status = ingest_status(dataset) %>
            <% ingest_cell_class = get_ingest_cell_class(ingest_status) %>
            <% ingest_status_html = get_html_from_ingest_status(ingest_status) %>

            <tr class="datasets-table__tr">
              <td class="datasets-table__cell datasets-table__cell--break datasets-table__ingested-cell--<%= ingest_cell_class %>" style="width: 10%;"><%= ingest_status_html %></td>
              <td class="datasets-table__cell datasets-table__cell--break datasets-table__data-title-cell"><%= dataset["data_title"] %></td>
              <td class="datasets-table__cell datasets-table__cell--break"><%= dataset["org_title"] %></td>
              <td class="datasets-table__cell datasets-table__cell--break" style="width: 10%;"><%= Link.link("Edit", to: "/datasets/#{dataset["id"]}", class: "btn") %></td>
            </tr>
          <% end %>
        <% end %>
      </table>
    </div>
    """
  end

  defp get_html_from_ingest_status(""), do: ""
  defp get_html_from_ingest_status("Failure") do
    ~E(
      <div class="ingestion-status">
        <div class="ingestion-failure-icon"></div>
        <div class="ingestion-failure-text">Failure</div>
      </div>
    )
  end

  defp get_html_from_ingest_status("Success") do
    ~E(
      <div class="ingestion-status">
        <div class="ingestion-success-icon"></div>
        <div class="ingestion-success-text">Success</div>
      </div>
    )
  end

  defp get_ingest_cell_class(""), do: "unset"
  defp get_ingest_cell_class(ingest_status), do: String.downcase(ingest_status)

  defp ingest_status(%{"ingested_time" => dataset_ingested_time} = dataset) when dataset_ingested_time != nil do
    dlq_message = Datasets.get(dataset["id"]) |> Map.get(:dlq_message)
    dlq_message_age_in_days = dlq_message_age(dlq_message)

    case dlq_message == nil or dlq_message_age_in_days > 7 do
      true -> "Success"
      _ -> "Failure"
    end
  end

  defp ingest_status(dataset), do: ""

  defp dlq_message_age(nil), do: -1

  defp dlq_message_age(dlq_message) do
    {:ok, dlq_message_timestamp, _} = dlq_message |> Map.get("timestamp") |> DateTime.from_iso8601()

    Timex.diff(DateTime.utc_now(), dlq_message_timestamp, :days)
  end
end
