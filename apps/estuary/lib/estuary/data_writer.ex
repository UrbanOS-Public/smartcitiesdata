defmodule Estuary.DataWriter do
  @moduledoc """
  Implementation of `Pipeline.Writer` for Estuary's edges.
  """

  @behaviour Pipeline.Writer

  @table_writer Application.get_env(:estuary, :table_writer)

  alias Estuary.Datasets.DatasetSchema

  @impl Pipeline.Writer
  @doc """
  Ensures a table exists using `:table_writer` from
  Estuary's application environment.
  """

  def init(args) do
    :ok =
      args
      |> @table_writer.init()
  rescue
    e -> {:error, e, "Presto Error"}
  end

  @impl Pipeline.Writer
  @doc """
  Writes data to PrestoDB and Kafka using `:table_writer` from
  Estuary's application environment.
  """

  def write(data, _opts \\ []) do
    :ok =
      data
      |> @table_writer.write(
        table: DatasetSchema.table_name(),
        schema: DatasetSchema.schema()
      )
  rescue
    _ -> {:error, data, "Presto Error"}
  end
end
