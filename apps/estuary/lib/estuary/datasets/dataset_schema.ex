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

<<<<<<< HEAD
  def make_datawriter_payload(event) do
    [
      %{
        payload: %{
          "author" => event.author,
          "create_ts" => event.create_ts,
          "data" => Jason.encode(event.data),
          "type" => event.type
=======
  def parse_event_args(dataset) do
    [
      %{
        payload: %{
          "author" => dataset.author,
          "create_ts" => dataset.create_ts,
          "data" => dataset.data,
          "type" => dataset.type
>>>>>>> Adding unit test and faker
        }
      }
    ]
  end

  def event_args do
    %{
      "author" => _,
      "create_ts" => _,
      "data" => _,
      "type" => _
    }
  end
end
