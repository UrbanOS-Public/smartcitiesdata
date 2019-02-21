defmodule Forklift.DatasetRegistryServer do
  @moduledoc false
  require Logger
  use GenServer

  alias Forklift.DatasetSchema

  ################
  ## Client API ##
  ################
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, [], Keyword.put_new(opts, :name, __MODULE__))
  end

  def get_schema(dataset_id) do
    GenServer.call(__MODULE__, {:get_schema, dataset_id})
  end

  def send_message(message) do
    with :ok <- start_server() do
      GenServer.call(__MODULE__, {:ingest_message, message})
    else
      {:error, e} -> raise RuntimeError, "Something went wrong (#{e})"
    end
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

  def handle_call({:ingest_message, message}, _from, _state) do
    IO.puts("DatasetRegistryServer: Received 1 message")

    message
    |> Jason.decode!()
    |> parse_schema()
    |> store_schema_ets()
    |> make_reply()
  end

  #######################
  ## Private Functions ##
  #######################
  defp start_server do
    case __MODULE__.start_link() do
      {:ok, _pid} -> :ok
      {:error, {:already_started, __pid}} -> :ok
      e -> {:error, e}
    end
  end

  defp init_ets_table do
    :ets.new(:dataset_registry, [:set, :protected, :named_table])
  end

  def get_schema_ets(dataset_id) do
    [{_id, schema}] = :ets.lookup(:dataset_registry, dataset_id)

    schema
  end

  defp store_schema_ets(%DatasetSchema{id: id} = schema) do
    :ets.insert(:dataset_registry, {id, schema})
  end

  defp store_schema_ets(:invalid_schema) do
    IO.puts("Schema Entry Invalid. Skipping storing for now.")
  end

  defp make_reply(msg), do: {:reply, msg, nil}

  defp parse_schema(%{"id" => id, "operational" => %{"schema" => schema}}) do
    columns = Enum.map(schema, fn %{"name" => name, "type" => type} -> {name, type} end)

    %DatasetSchema{
      id: id,
      columns: columns
    }
  end

  defp parse_schema(schema_map) do
    Logger.info("Schema Entry Invalid. Skipping for now.")
    :invalid_schema
  end
end
