defmodule Estuary.Services.EventRetrievalService do
  @moduledoc """
  Interface for retrieving events.
  """
  alias Estuary.Datasets.DatasetSchema
  alias Estuary.Query.Helper.PrestigeHelper

  def get_all do
    "SELECT events.author, events.create_ts, events.data, events.type
    FROM (SELECT author, create_ts, data, type
    FROM #{DatasetSchema.table_name()}
    WHERE create_ts >= to_unixtime(now() - interval '3' hour) LIMIT 1000) events
    ORDER BY events.create_ts DESC"
    |> PrestigeHelper.execute_query()
  end
end
