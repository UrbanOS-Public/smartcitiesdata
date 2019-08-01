defmodule Andi.EventHandler do
  @moduledoc "Event Handler for event stream"
  use Brook.Event.Handler
  require Logger

  def handle_event(%Brook.Event{type: "dataset:update", data: data}) do
    case SmartCity.Dataset.new(data) do
      {:ok, dataset} ->
        {:merge, :dataset, dataset.id, dataset}

      {:error, err} ->
        Logger.error("Unable to parse dataset (#{inspect(err)}): #{inspect(data)}")
        :discard
    end
  end

  def handle_event(%Brook.Event{type: "org:update", data: data}) do
    case SmartCity.Organization.new(data) do
      {:ok, org} ->
        {:merge, :org, org.id, org}

      {:error, err} ->
        Logger.error("Unable to parse organization (#{inspect(err)}): #{inspect(data)}")
        :discard
    end
  end
end
