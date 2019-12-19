defmodule XMLStream.SaxHandler do
  @moduledoc false

  defmodule State do
    @moduledoc false
    @enforce_keys [:tag_path, :emitter]
    defstruct stack: [], accumulate: false, tag_stack: [], tag_path: [], emitter: nil

    def new(fields \\ %{}) do
      struct!(__MODULE__, fields)
    end

    def update(%__MODULE__{} = state, fields) do
      struct!(state, fields)
    end

    @spec pop(%State{}, :stack | :tag_stack | :tag_path) :: {any(), %State{}}
    def pop(%__MODULE__{} = state, key) when key in [:stack, :tag_stack, :tag_path] do
      [item | rest] = Map.fetch!(state, key)

      {item, State.update(state, [{key, rest}])}
    end

    def pop_current_tag(%__MODULE__{} = state, tag_name) do
      {{^tag_name, attributes, content}, state} = State.pop(state, :stack)

      {{tag_name, attributes, Enum.reverse(content)}, state}
    end

    def at_path?(%__MODULE__{tag_stack: tag_stack, tag_path: tag_path}, tag_name) do
      [tag_name | tag_stack] == tag_path
    end

    def ascend(%__MODULE__{} = state) do
      State.pop(state, :tag_stack)
    end

    def descend(%__MODULE__{tag_stack: tag_stack} = state, tag_name) do
      State.update(state, tag_stack: [tag_name | tag_stack])
    end
  end

  @behaviour Saxy.Handler
  @file_chunk_size 40_000

  ######################
  ## Client Functions ##
  ######################
  def start_stream(filepath, tag_path_string, callback) when is_function(callback, 1) do
    tag_path = parse_selector(tag_path_string)

    filepath
    |> File.stream!([], @file_chunk_size)
    |> handle_ufeff()
    |> Saxy.parse_stream(
      __MODULE__,
      __MODULE__.State.new(tag_path: tag_path, emitter: callback)
    )
  end

  ###############
  ## Callbacks ##
  ###############
  @impl true
  def handle_event(:start_document, _, %State{} = state) do
    ok(state)
  end

  @impl true
  def handle_event(:end_document, _, %State{} = state) do
    ok(state)
  end

  @impl true
  def handle_event(:start_element, {tag_name, attributes}, %State{} = state) do
    if State.at_path?(state, tag_name) or state.accumulate do
      tag = {tag_name, attributes, []}

      state
      |> State.descend(tag_name)
      |> State.update(stack: [tag | state.stack], accumulate: true)
      |> ok()
    else
      state
      |> State.descend(tag_name)
      |> ok()
    end
  end

  @impl true
  def handle_event(:characters, chars, %State{stack: stack, accumulate: true} = state) do
    [{tag_name, attributes, content} | stack] = stack

    current = {tag_name, attributes, [{:characters, chars} | content]}

    state
    |> State.update(stack: [current | stack])
    |> ok()
  end

  def handle_event(:characters, _chars, %State{accumulate: false} = state), do: ok(state)

  @impl true
  def handle_event(:end_element, tag_name, %State{accumulate: true} = state) do
    {^tag_name, state} = State.ascend(state)
    {current_tag, state} = State.pop_current_tag(state, tag_name)

    should_emit = State.at_path?(state, tag_name)

    case state.stack do
      [] when should_emit ->
        state.emitter.(current_tag)

        state
        |> State.update(accumulate: false)
        |> ok()

      [] ->
        state
        |> State.update(stack: [current_tag])
        |> ok()

      [parent | rest] ->
        parent = update_parent(parent, current_tag)

        state
        |> State.update(stack: [parent | rest])
        |> ok()
    end
  end

  def handle_event(:end_element, _tag_name, %State{accumulate: false} = state) do
    {_tag, state} = State.ascend(state)

    ok(state)
  end

  #######################
  ## Private Functions ##
  #######################
  @spec ok(%State{}) :: {:ok, %State{}}
  defp ok(%State{} = state), do: {:ok, state}

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

  defp update_parent({tag_name, attributes, content} = _parent_tag, child_tag) do
    {tag_name, attributes, [child_tag | content]}
  end
end
