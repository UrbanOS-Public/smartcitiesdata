defmodule Andi.EventHandler do
  @moduledoc "Event Handler for event stream"
  use Brook.Event.Handler
  require Logger
  import SmartCity.Events, only: [update_dataset: 0, update_organization: 0]

  def handle_event(%Brook.Event{type: update_dataset(), data: data}) do
    case SmartCity.Dataset.new(data) do
      {:ok, dataset} ->
        {:merge, :dataset, dataset.id, dataset}

      {:error, err} ->
        Logger.error("Unable to parse dataset (#{inspect(err)}): #{inspect(data)}")
        :discard
    end
  end

  def handle_event(%Brook.Event{type: update_organization(), data: data}) do
    case SmartCity.Organization.new(data) do
      {:ok, org} ->
        {:merge, :org, org.id, org}

      {:error, err} ->
        Logger.error("Unable to parse organization (#{inspect(err)}): #{inspect(data)}")
        :discard
    end
  end
end
