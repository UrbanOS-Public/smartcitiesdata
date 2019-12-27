defmodule Estuary.DataWriter do
  @moduledoc """
  Implementation of `Pipeline.Writer` for Estuary's edges.
  """

  @table_writer Application.get_env(:estuary, :table_writer)

  alias Estuary.Datasets.DatasetSchema

  @impl Pipeline.Writer
  @doc """
  Ensures a table exists using `:table_writer` from Estuary's application environment.
  """
  def init(args) do
    :ok =
      args
      |> @table_writer.init()
  end

  @impl Pipeline.Writer
  @doc """
  Writes data to PrestoDB and Kafka using `:table_writer` from
  Estuary's application environment.
  """

  def write(data) do
    :ok =
      data
      |> @table_writer.write(
        table: DatasetSchema.table_name(),
        schema: DatasetSchema.schema()
      )
  rescue
    e -> {:error, e, "Presto Error"}
  end
end
