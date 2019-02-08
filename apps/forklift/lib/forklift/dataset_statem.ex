defmodule DatasetStatem do
  alias :gen_statem, as: GenStatem
  @behaviour GenStatem

  alias Forklift.PrestoClient

  @batch_size 5_000
  @timeout 6_000

  ##################
  ## State Struct ##
  ##################
  defmodule State do
    defstruct dataset_id: nil, messages: []

    def set_messages(state, messages \\ []) do
      %State{state | messages: messages}
    end
  end

  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: { __MODULE__, :start_link, [opts]},
      restart: :temporary,
      shutdown: 5000,
      type: :worker,
    }
  end

  ################
  ## Client API ##
  ################
  def start_link(dataset_id, opts \\ []) do
    GenStatem.start_link(__MODULE__, dataset_id, opts)
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
  def init(dataset_id) do
    {:ok, :no_messages, %State{dataset_id: dataset_id}}
  end

  def no_messages({:call, from}, {:ingest_message, message}, %State{dataset_id: dataset_id, messages: messages}=state) do
    timeout_action = {:state_timeout, @timeout, :any}
    reply = make_reply(from, :ok)

    case maybe_upload(dataset_id, [message | messages]) do
      :uploaded -> {:keep_state, State.set_messages(state), [reply]} |> IO.inspect(label: "dataset_statem.ex:56")
      {:buffering, message_set} -> {:next_state, :buffering_messages, State.set_messages(state, message_set), [reply, timeout_action]} |> IO.inspect(label: "dataset_statem.ex:57")
    end
  end

  def buffering_messages({:call, from}, {:ingest_message, message}, %State{dataset_id: dataset_id, messages: messages}=state) do
    reply = make_reply(from, :ok)

    case maybe_upload(dataset_id, [message | messages]) do
      :uploaded -> {:next_state, :no_messages, State.set_messages(state), [reply]} |> IO.inspect(label: "dataset_statem.ex:65")
      {:buffering, message_set} -> {:keep_state, State.set_messages(state, message_set), [reply]} |> IO.inspect(label: "dataset_statem.ex:66")
    end
  end
  def buffering_messages(event, event_content, state) do
    {event, event_content} |> IO.inspect(label: "A TIMEOUTE HAPPENED")
    {:keep_state, state}
  end

  #######################
  ## Private Functions ##
  #######################
  def maybe_upload(dataset_id, messages) when length(messages) >= @batch_size do
    with :ok <- PrestoClient.upload_data(dataset_id, messages) do
      :uploaded
    end
  end

  def maybe_upload(_dataset_id, messages) do
    {:buffering, messages}
  end

  def make_reply(from, message), do: {:reply, from, message}

end
