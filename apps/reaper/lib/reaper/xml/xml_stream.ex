defmodule XMLStream do
  use GenStage

  @chunk_size 40_000

  defmodule State do
    @enforce_keys []
    defstruct demand: 0, blocked: nil, parser_pid: nil, monitor_ref: nil, filepath: nil, top_level_selector: nil

    def new(fields \\ %{}) do
      struct(__MODULE__, fields)
    end

    def update(%__MODULE__{} = state, fields) do
      struct!(state, fields)
    end
  end

  def do_stream(path, tls) do
    {:ok, pid} = GenStage.start_link(__MODULE__, {path, tls})
    GenStage.stream([{pid, max_demand: 1, cancel: :transient}])
    # |> Stream.map(&Saxy.encode!/1)
  end

  ###############
  ## Callbacks ##
  ###############
  def init({path, tls}) do
    {:producer, State.new(filepath: path, top_level_selector: tls)}
  end

  def handle_call({:emit, record}, _from, %State{demand: demand} = state) when demand > 1 do
    {:reply, :ok, [record], Map.update!(state, :demand, &(&1 - 1))}
  end

  def handle_call({:emit, record}, from, state) do
    {:noreply, [record], State.update(state, demand: 0, blocked: from)}
  end

  def handle_cancel({:cancel, reason}, _from, state) do
    {:stop, reason, state}
  end

  def handle_subscribe(:consumer, _opts, _from, %State{filepath: path, top_level_selector: tls} = state) do
    parent = self()

    pid = spawn_link(fn -> start_stream(path, tls, parent) end)
    Process.monitor(pid)

    {:automatic, State.update(state, parser_pid: pid, demand: 0, blocked: nil, filepath: path, top_level_selector: tls)}
  end

  def handle_demand(demand, state) do
    if state.blocked != nil do
      GenStage.reply(state.blocked, :ok)
    end

    {:noreply, [], Map.update!(state, :demand, &(&1 + demand))}
  end

  def handle_info({:DOWN, _ref, :process, _pid, reason}, state) do
    {:stop, reason, state}
  end

  #######################
  ## Private Functions ##
  #######################
  defp start_stream(path, selector, parent) do
    selector = parse_selector(selector)

    path
    |> File.stream!([], @chunk_size)
    |> handle_ufeff()
    |> Saxy.parse_stream(
      XMLStream.SaxHandler,
      XMLStream.SaxHandler.State.new(tag_path: selector, emitter: &GenStage.call(parent, {:emit, &1}, :infinity))
    )
  end

  defp handle_ufeff(stream) do
    Stream.transform(stream, false, &ufeff_reducer/2)
  end

  defp ufeff_reducer(bytes, true), do: {[bytes], true}
  defp ufeff_reducer(<<"\uFEFF" <> bytes>>, false), do: {[bytes], true}
  defp ufeff_reducer(bytes, false), do: {[bytes], true}

  defp parse_selector(selector) when is_binary(selector) do
    selector
    |> String.split("/")
    |> Enum.reverse()
  end
end
