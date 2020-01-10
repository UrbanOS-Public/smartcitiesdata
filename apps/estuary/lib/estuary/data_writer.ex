defmodule Estuary.DataWriter do
  @moduledoc """
  Implementation of `Pipeline.Writer` for Estuary's edges.
  """

  alias Estuary.Datasets.DatasetSchema

  @behaviour Pipeline.Writer

  @table_writer Application.get_env(:estuary, :table_writer)

  @impl Pipeline.Writer
  @doc """
  Ensures a table exists using `:table_writer` from
  Estuary's application environment.
  """
  def init(args) do
    :ok = @table_writer.init(args)
  rescue
    e -> {:error, e, "Presto Error"}
  end

  @impl Pipeline.Writer
  @doc """
  Writes data to PrestoDB and Kafka using `:table_writer` from
  Estuary's application environment.
  """
  def write(events, _ \\ []) do
    # if bad events, return, else write
    :ok =
      events
      |> make_datawriter_payload()
      |> @table_writer.write(
        table: DatasetSchema.table_name(),
        schema: DatasetSchema.schema()
      )
  rescue
    _ -> {:error, events, "Presto Error"}
  end

  defp make_datawriter_payload(events) do
    Enum.map(events, &make_payload/1)
  end

  defp make_payload(%{
         "author" => author,
         "create_ts" => create_ts,
         "data" => data,
         "type" => type
       }) do
    %{
      payload: %{
        "author" => author,
        "create_ts" => create_ts,
        "data" => data,
        "type" => type
      }
    }
  end

  def make_payload(event, _) do
    {:error, event, "Required field missing"}
  end
end
