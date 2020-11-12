defmodule Estuary.DataWriter do
  @moduledoc """
  Implementation of `Pipeline.Writer` for Estuary's edges.
  """
  use Properties, otp_app: :estuary

  require Logger

  alias Estuary.Datasets.DatasetSchema
  alias Estuary.DataReader

  @behaviour Pipeline.Writer

  getter(:table_writer, generic: true)
  getter(:table_name, generic: true)

  @impl Pipeline.Writer
  @doc """
  Ensures a table exists using `:table_writer` from
  Estuary's application environment.
  """
  def init(args) do
    :ok = table_writer().init(args)
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
        table_writer().write(payload,
          table: table_name(),
          schema: DatasetSchema.schema()
        )

      _ ->
        {:error, events, "Required field missing"}
    end
  rescue
    _ -> {:error, events, "Presto Error"}
  end

  @impl Pipeline.Writer
  def compact(_ \\ []) do
    Logger.info("Beginning #{table_name()} compaction")
    DataReader.terminate()
    table_writer().compact(table: table_name())
    DataReader.init()
    Logger.info("Completed #{table_name()} compaction")
    :ok
  rescue
    error ->
      Logger.error("#{table_name()} failed to compact: #{inspect(error)}")
      {:error, error}
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
