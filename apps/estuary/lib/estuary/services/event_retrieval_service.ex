defmodule Estuary.Services.EventRetrievalService do
  @behaviour Estuary.Services.EventRetrievalServiceBehaviour
  @moduledoc """
  Interface for retrieving events.
  """
  use Properties, otp_app: :estuary

  alias Estuary.Datasets.DatasetSchema
  alias Estuary.Query.Helper.PrestigeHelper

  getter(:table_name, generic: true)

  def get_all do
    """
    SELECT author, create_ts, data, type
    FROM #{table_name()}
    ORDER BY create_ts DESC
    LIMIT 500
    """
    |> PrestigeHelper.execute_query_stream()
  end
end
