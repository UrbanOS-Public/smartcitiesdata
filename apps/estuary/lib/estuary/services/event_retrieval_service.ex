defmodule Estuary.Services.EventRetrievalService do
  @moduledoc """
  Interface for retrieving events.
  """
  alias Estuary.Datasets.DatasetSchema
  alias Estuary.Query.Helper.PrestigeHelper

  def get_all do
    """
    SELECT author, create_ts, data, type
    FROM #{DatasetSchema.table_name()}
    ORDER BY create_ts DESC
    LIMIT 500
    """
    |> PrestigeHelper.execute_query_stream()
  end
end
