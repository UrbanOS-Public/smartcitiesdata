defmodule Estuary.Datasets.DatasetSchema do
  @moduledoc """
  The schema information that estuary persists and references for a given dataset
  """

  def table_schema() do
    [
      table: table_name(),
      schema: schema()
    ]
  end

  def table_name do
    Application.get_env(:estuary, :event_stream_table_name)
  end

  def schema do
    [
      %{
        name: "author",
        type: "string",
        description: "N/A"
      },
      %{
        name: "create_ts",
        type: "long",
        description: "N/A"
      },
      %{
        name: "data",
        type: "string",
        description: "N/A"
      },
      %{
        name: "type",
        type: "string",
        description: "N/A"
      }
    ]
  end

  def parse_event_args(dataset) do
    [
      %{
        payload: %{
          "author" => dataset.author,
          "create_ts" => dataset.create_ts,
          "data" => dataset.data,
          "type" => dataset.type
        }
      }
    ]
  end
end
