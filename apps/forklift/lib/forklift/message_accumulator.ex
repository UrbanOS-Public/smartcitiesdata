defmodule Forklift.MessageAccumulator do
  @moduledoc false
  require Logger
  alias :gen_statem, as: GenStatem
  @behaviour GenStatem

  alias Forklift.PrestoClient

  @batch_size Application.fetch_env!(:forklift, :batch_size)
  @timeout Application.fetch_env!(:forklift, :timeout)

  ##################
  ## State Struct ##
  ##################
  defmodule Data do
    @moduledoc false
    defstruct dataset_id: nil, messages: [], batch_size: nil, timeout: nil

    def set_messages(data, messages \\ []) do
      %Data{data | messages: messages}
    end
  end

  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      restart: :temporary,
      shutdown: 5000,
      type: :worker
    }
  end

  ################
  ## Client API ##
  ################
  def start_link(dataset_id, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, @timeout)
    batch_size = Keyword.get(opts, :batch_size, @batch_size)

    GenStatem.start_link(
      via_tuple(dataset_id),
      __MODULE__,
      {dataset_id, timeout, batch_size},
      opts
    )
  end

  def send_message(pid, message) do
    GenStatem.call(pid, {:ingest_message, message})
  end

  ######################
  ## Server Callbacks ##
  ######################
  @impl GenStatem
  def callback_mode do
    :state_functions
  end

  @impl GenStatem
  def init({dataset_id, timeout, batch_size}) do
    {:ok, :no_messages, %Data{dataset_id: dataset_id, timeout: timeout, batch_size: batch_size}}
  end

  def no_messages(
        {:call, from},
        {:ingest_message, message},
        %Data{dataset_id: dataset_id, messages: messages} = data
      ) do
    timeout_action = {:state_timeout, data.timeout, :any}
    reply = make_reply(from, :ok)

    case maybe_upload(dataset_id, [message | messages], data.batch_size) do
      :uploaded ->
        {:keep_state, Data.set_messages(data), [reply]}

      {:buffering, message_set} ->
        {:next_state, :buffering_messages, Data.set_messages(data, message_set), [reply, timeout_action]}

      other ->
        Logger.info("Unhandled upload error found in accumulator: #{other}")
    end
  end

  def buffering_messages(
        {:call, from},
        {:ingest_message, message},
        %Data{dataset_id: dataset_id, messages: messages} = data
      ) do
    reply = make_reply(from, :ok)

    case maybe_upload(dataset_id, [message | messages], data.batch_size) do
      :uploaded -> {:next_state, :no_messages, Data.set_messages(data), [reply]}
      {:buffering, message_set} -> {:keep_state, Data.set_messages(data, message_set), [reply]}
    end
  end

  def buffering_messages(:state_timeout, _event_content, %Data{messages: messages} = data) do
    PrestoClient.upload_data(data.dataset_id, messages)
    {:next_state, :no_messages, Data.set_messages(data)}
  end

  #######################
  ## Private Functions ##
  #######################
  defp maybe_upload(dataset_id, messages, batch_size) when length(messages) >= batch_size do
    with :ok <- PrestoClient.upload_data(dataset_id, messages) do
      :uploaded
    end
  end

  defp maybe_upload(_dataset_id, messages, _batch_size) do
    {:buffering, messages}
  end

  defp make_reply(from, message), do: {:reply, from, message}

  def via_tuple(dataset_id), do: {:via, Registry, {Forklift.Registry, dataset_id}}
end
