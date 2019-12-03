defmodule StreamyBoiXml do
  alias TheBestHandler
  alias TheBestHandler.State

  @byte_size 40_000
  def stream_xml(path, tls, stream_opts \\ []) do
    Stream.resource(
      _start_fn = fn ->
        _waiter = {parent, ref} = {self(), make_ref()}
        emitter = fn emitee -> send(parent, {:emit, ref, emitee}) end

        pid = spawn_link(fn -> start_stream(path, tls, emitter, stream_opts) end)

        {ref, pid, Process.monitor(pid)}
      end,
      _next_fn = fn {ref, _pid, monref} = acc ->
        receive do
          {:emit, ^ref, emitee} ->
            {[emitee], acc}

          {:DOWN, ^monref, _, _, _} ->
            {:halt, :parse_ended}
        end
      end,
      _after_fn = fn
        :parse_ended ->
          :ok

        {_ref, pid, monref} ->
          Process.demonitor(monref)
          Process.unlink(pid)
          Process.exit(pid, :stream_finished)
      end
    )
  end

  defp handle_ufeff(stream) do
    Stream.transform(stream, false, &ufeff_reducer/2)
  end

  defp ufeff_reducer(bytes, true), do: {[bytes], true}
  defp ufeff_reducer(<<"\uFEFF" <> bytes>>, false), do: {[bytes], true}
  defp ufeff_reducer(bytes, false), do: {[bytes], true}

  defp start_stream(path, tls, emitter, opts) do
    path
    |> File.stream!(opts, @byte_size)
    |> handle_ufeff()
    |> Saxy.parse_stream(TheBestHandler, State.new(tag_path: tls, emitter: emitter), expand_entity: :skip)
  end
end

defmodule Mailman do
  def get_all, do: do_get_all()

  def peek(pid \\ nil) do
    {:messages, messages} = :erlang.process_info(pid || self(), :messages)

    messages
  end

  defp do_get_all(msgs \\ []) do
    receive do
      msg -> do_get_all([msg | msgs])
    after
      0 -> msgs
    end
  end
end
