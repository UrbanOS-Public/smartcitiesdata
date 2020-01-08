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
  def write(event, opts \\ [])

  def write(%{"author" => _, "create_ts" => _, "data" => _, "type" => _} = event, _) do
    :ok =
      event
      |> make_datawriter_payload()
      |> @table_writer.write(
        table: DatasetSchema.table_name(),
        schema: DatasetSchema.schema()
      )
  rescue
    _ -> {:error, event, "Presto Error"}
  end

  def write(event, _) do
    {:error, event, "Required field missing"}
  end

  defp make_datawriter_payload(event) do
    [
      %{
        payload: %{
          "author" => event["author"],
          "create_ts" => event["create_ts"],
          "data" => event["data"],
          "type" => event["type"]
        }
      }
    ]
  end
end
