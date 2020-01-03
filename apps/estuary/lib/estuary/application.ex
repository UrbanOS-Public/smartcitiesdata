defmodule Estuary.Application do
  @moduledoc false
  use Application

  alias Estuary.DataWriter
  alias Estuary.DataReader
  alias Estuary.Datasets.DatasetSchema

  def start(_type, _args) do
    DatasetSchema.table_schema()
    |> Estuary.DataWriter.init()

    DataReader.init()

    [
      {DynamicSupervisor, strategy: :one_for_one, name: Estuary.Dynamic.Supervisor},
      {DeadLetter, Application.get_env(:estuary, :dead_letter)},
      {Estuary.InitServer, []}
    ]
    |> List.flatten()
    |> Supervisor.start_link(strategy: :one_for_one, name: Estuary.Supervisor)
  end
end
