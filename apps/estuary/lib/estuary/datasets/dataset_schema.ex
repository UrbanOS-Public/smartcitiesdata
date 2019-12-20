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

  def make_datawriter_payload(event) do
    [
      %{
        payload: %{
          "author" => event.author,
          "create_ts" => event.create_ts,
          "data" => event.data,
          "type" => event.type
        }
      }
    ]
  end
end
