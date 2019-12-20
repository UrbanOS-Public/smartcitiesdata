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
    args
    |> @table_writer.init()
  end

  @impl Pipeline.Writer
  @doc """
  Writes data to PrestoDB and Kafka using `:table_writer` from
  Estuary's application environment.
  """

  def write() do
    # def write(data, opts) do
    # IO.inspect(data)
    # IO.inspect(metadata)
    # :ok <- @table_writer.write(data, table: table_name(), parse_args(metadata))
    # :ok <-
    DatasetSchema.dataset()
    |> DatasetSchema.parse_event_args()

  def write(data, opts) do
    # IO.inspect(data)
    # IO.inspect(metadata)
    # :ok <- @table_writer.write(data, table: table_name(), parse_args(metadata))
    :ok <- DatasetSchema.dataset()
    |> DatasetSchema.parse_args()

  def write() do
    # def write(data, opts) do
    # IO.inspect(data)
    # IO.inspect(metadata)
    # :ok <- @table_writer.write(data, table: table_name(), parse_args(metadata))
    # :ok <-
    DatasetSchema.dataset()
    |> DatasetSchema.parse_event_args()
    |> @table_writer.write(
      table: DatasetSchema.table_name(),
      schema: DatasetSchema.schema()
    )
  end
end
