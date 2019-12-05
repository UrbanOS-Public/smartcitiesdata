defmodule XMLStream do
  @moduledoc """
  Extracts a stream of records from an XML document with minimal memory overhead
  """
  use GenStage

  alias XMLStream.SaxHandler

  defmodule State do
    @moduledoc false
    @enforce_keys [:filepath, :top_level_selector]
    defstruct demand: 0, blocked: nil, parser_pid: nil, monitor_ref: nil, filepath: nil, top_level_selector: nil

    def new(fields \\ %{}) do
      struct!(__MODULE__, fields)
    end

    def update(%__MODULE__{} = state, fields) do
      struct!(state, fields)
    end
  end

  ######################
  ## Client Functions ##
  ######################
  @doc """
  Creates a stream of records found at the given path in the document as XML strings that can then be parsed using xpaths.

  Tag path is inclusive, i.e. the last element should be the record tag.

  ## Example
    With the following XML:
    ```
    <response>
      <row id="1" />
      <row id="2" />
    </response>
    ```

    The tag path would be:
    ```
    tag_path = "response/row"
    ```

    The stream would emit:
    ```
    ["<row id=\"1\"></row>", "<row id=\"2\"></row>"]
    ```
  """
  def stream(filepath, tag_path) do
    {:ok, pid} = GenStage.start_link(__MODULE__, {filepath, tag_path})

    GenStage.stream([{pid, max_demand: 1, cancel: :transient}])
    |> Stream.map(&Saxy.encode!/1)
  end

  ###############
  ## Callbacks ##
  ###############
  def init({filepath, tag_path}) do
    {:producer, State.new(filepath: filepath, top_level_selector: tag_path)}
  end

  def handle_call({:emit, record}, _from, %State{demand: demand} = state) when demand > 1 do
    {:reply, :ok, [record], Map.update!(state, :demand, &(&1 - 1))}
  end

  def handle_call({:emit, record}, from, state) do
    {:noreply, [record], State.update(state, demand: 0, blocked: from)}
  end

  def handle_demand(demand, state) do
    if state.blocked != nil do
      GenStage.reply(state.blocked, :ok)
    end

    {:noreply, [], Map.update!(state, :demand, &(&1 + demand))}
  end

  def handle_subscribe(:consumer, _opts, _from, %State{filepath: path, top_level_selector: tls} = state) do
    parent = self()

    pid = spawn_link(fn -> SaxHandler.start_stream(path, tls, &GenStage.call(parent, {:emit, &1}, :infinity)) end)
    monitor_ref = Process.monitor(pid)

    {:automatic,
     State.update(state,
       parser_pid: pid,
       monitor_ref: monitor_ref,
       demand: 0,
       blocked: nil,
       filepath: path,
       top_level_selector: tls
     )}
  end

  def handle_cancel({:cancel, reason}, _from, state) do
    {:stop, reason, state}
  end

  def handle_info({:DOWN, _ref, :process, _pid, reason}, state) do
    {:stop, reason, state}
  end
end
