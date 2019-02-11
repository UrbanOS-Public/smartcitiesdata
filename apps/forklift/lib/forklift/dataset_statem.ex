defmodule Forklift.DatasetStatem do
  alias :gen_statem, as: GenStatem
  @behaviour GenStatem

  alias Forklift.PrestoClient

  @batch_size 5_000
  @timeout 60_000

  ##################
  ## State Struct ##
  ##################
  defmodule State do
    defstruct dataset_id: nil, messages: [], batch_size: nil, timeout: nil

    def set_messages(state, messages \\ []) do
      %State{state | messages: messages}
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

    GenStatem.start_link(__MODULE__, {dataset_id, timeout, batch_size}, opts)
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
    {:ok, :no_messages, %State{dataset_id: dataset_id, timeout: timeout, batch_size: batch_size}}
  end

  def no_messages(
        {:call, from},
        {:ingest_message, message},
        %State{dataset_id: dataset_id, messages: messages} = state
      ) do
    timeout_action = {:state_timeout, state.timeout, :any}
    reply = make_reply(from, :ok)

    case maybe_upload(dataset_id, [message | messages], state.batch_size) do
      :uploaded ->
        {:keep_state, State.set_messages(state), [reply]}

      {:buffering, message_set} ->
        {:next_state, :buffering_messages, State.set_messages(state, message_set),
         [reply, timeout_action]}
    end
  end

  def buffering_messages(
        {:call, from},
        {:ingest_message, message},
        %State{dataset_id: dataset_id, messages: messages} = state
      ) do
    reply = make_reply(from, :ok)

    case maybe_upload(dataset_id, [message | messages], state.batch_size) do
      :uploaded -> {:next_state, :no_messages, State.set_messages(state), [reply]}
      {:buffering, message_set} -> {:keep_state, State.set_messages(state, message_set), [reply]}
    end
  end

  def buffering_messages(:state_timeout, _event_content, %State{messages: messages} = state) do
    PrestoClient.upload_data(state.dataset_id, messages)
    {:next_state, :no_messages, State.set_messages(state)}
  end

  #######################
  ## Private Functions ##
  #######################
  def maybe_upload(dataset_id, messages, batch_size) when length(messages) >= batch_size do
    with :ok <- PrestoClient.upload_data(dataset_id, messages) do
      :uploaded
    end
  end

  def maybe_upload(_dataset_id, messages, _batch_size) do
    {:buffering, messages}
  end

  def make_reply(from, message), do: {:reply, from, message}
end
