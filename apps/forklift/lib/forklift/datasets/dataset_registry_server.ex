defmodule Forklift.Datasets.DatasetRegistryServer do
  @moduledoc """
  Server for the persitance and retrieval of dataset registry schemas
  """
  require Logger
  use GenServer

  alias Forklift.Datasets.DatasetSchema

  ################
  ## Client API ##
  ################
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, [], Keyword.put_new(opts, :name, __MODULE__))
  end

  @doc """
  Get the schema of a dataset

  Example

    iex> Forklift.Datasets.DatasetRegistryServer.get_schema("123")
    %Forklift.Datasets.DatasetSchema{columns: [%{name: "id", type: "int"}, %{name: "name", type: "string"}], id: "123", system_name: "system__name" }
  """
  def get_schema(dataset_id) do
    GenServer.call(__MODULE__, {:get_schema, dataset_id})
  end

  @doc """
  Store a dataset's schema
  """
  def send_message(%SmartCity.Dataset{} = message) do
    GenServer.call(__MODULE__, {:ingest_message, message})
  end

  ######################
  ## Server Callbacks ##
  ######################
  def init(_args) do
    init_ets_table()

    {:ok, nil}
  end

  def handle_call({:get_schema, dataset_id}, _from, _state) do
    dataset_id
    |> get_schema_ets()
    |> make_reply()
  end

  def handle_call({:ingest_message, registry_message}, _from, _state) do
    IO.puts("DatasetRegistryServer: Received 1 message")

    registry_message
    |> parse_schema()
    |> store_schema_ets()
    |> make_reply()
  end

  #######################
  ## Private Functions ##
  #######################
  defp init_ets_table do
    :ets.new(:dataset_registry, [:set, :protected, :named_table])
  end

  defp get_schema_ets(dataset_id) do
    case :ets.lookup(:dataset_registry, dataset_id) do
      [{_id, schema}] ->
        schema

      _ ->
        Logger.warn("A schema has not been loaded for #{dataset_id}.")
        nil
    end
  end

  defp store_schema_ets(%DatasetSchema{id: id} = schema) do
    :ets.insert(:dataset_registry, {id, schema})
  end

  defp store_schema_ets(:invalid_schema) do
    IO.puts("Schema Entry Invalid. Skipping storing for now.")
  end

  defp make_reply(msg), do: {:reply, msg, nil}

  defp parse_schema(%SmartCity.Dataset{:id => id, :technical => %{:schema => schema, :systemName => system_name}}) do
    %DatasetSchema{
      id: id,
      system_name: system_name,
      columns: schema
    }
  end

  defp parse_schema(_schema_map) do
    Logger.info("Schema Entry Invalid. Skipping for now.")
    :invalid_schema
  end
end
