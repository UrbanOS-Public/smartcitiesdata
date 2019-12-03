defmodule XMLStream.SaxHandler do
  @moduledoc false

  defmodule State do
    @enforce_keys [:stack, :accumulate, :tag_stack, :tag_path, :emitter]
    defstruct stack: [], accumulate: false, tag_stack: [], tag_path: [], emitter: nil

    def new(fields \\ %{}) do
      struct(__MODULE__, fields)
    end

    def update(state, fields) do
      struct!(state, fields)
    end
  end

  @behaviour Saxy.Handler

  defp ok(state), do: {:ok, state}

  def handle_event(:start_document, _, state) do
    ok(state)
  end

  def handle_event(:end_document, _, state) do
    ok(state)
  end

  def handle_event(:start_element, {tag_name, attributes}, %State{} = state) do
    state = State.update(state, tag_stack: [tag_name | state.tag_stack])

    if state.tag_stack == state.tag_path or state.accumulate do
      tag = {tag_name, attributes, []}

      state
      |> State.update(stack: [tag | state.stack], accumulate: true)
      |> ok()
    else
      ok(state)
    end
  end

  def handle_event(:characters, chars, %{stack: stack, accumulate: accumulate} = state) do
    if accumulate do
      [{tag_name, attributes, content} | stack] = stack

      current = {tag_name, attributes, [chars | content]}

      state
      |> State.update(stack: [current | stack])
      |> ok()
    else
      ok(state)
    end
  end

  def handle_event(
        :end_element,
        tag_name,
        %{stack: stack, accumulate: accumulate, tag_stack: [_stack_tag_name | tag_stack]} = state
      ) do
    state = %{state | tag_stack: tag_stack}

    if accumulate do
      [{^tag_name, attributes, content} | stack] = stack

      current = {tag_name, attributes, Enum.reverse(content)}

      case stack do
        [] ->
          if [tag_name | state.tag_stack] == state.tag_path do
            state.emitter.(current)

            state
            |> State.update(stack: [], accumulate: false)
            |> ok()
          else
            state
            |> State.update(stack: [current])
            |> ok()
          end

        [parent | rest] ->
          {parent_tag_name, parent_attributes, parent_content} = parent
          parent = {parent_tag_name, parent_attributes, [current | parent_content]}

          state
          |> State.update(stack: [parent | rest])
          |> ok()
      end
    else
      ok(state)
    end
  end
end
