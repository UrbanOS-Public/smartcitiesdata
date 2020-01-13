defmodule Estuary.DataWriter do
  @moduledoc """
  Implementation of `Pipeline.Writer` for Estuary's edges.
  """

  alias Estuary.Datasets.DatasetSchema

  @behaviour Pipeline.Writer

  @table_writer Application.get_env(:estuary, :table_writer)
  @table_name Application.get_env(:estuary, :table_name)

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
    payload = make_datawriter_payload(events)

    case get_errors(payload) do
      [] ->
        @table_writer.write(payload,
          table: DatasetSchema.table_name(),
          schema: DatasetSchema.schema()
        )

      _ ->
        {:error, events, "Required field missing"}
    end
  rescue
    _ -> {:error, events, "Presto Error"}
  end

  def compact_events() do
    @table_writer.compact(table: @table_name)
    :ok
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

  defp make_payload(event) do
    {:error, event, "Required field missing"}
  end

  defp get_errors(payload) do
    Enum.filter(payload, &match?({:error, _, _}, &1))
  end
end
