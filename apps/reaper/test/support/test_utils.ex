defmodule TestUtils do
  @moduledoc false

  @kafka_endpoint Application.get_env(:kaffe, :producer)[:endpoints]
                  |> Enum.map(fn {k, v} -> {k, v} end)
  @destination_topic Application.get_env(:kaffe, :producer)[:topics]
                     |> List.first()

  def feed_supervisor_count() do
    Reaper.Horde.Supervisor
    |> Horde.Supervisor.which_children()
    |> Enum.filter(&is_feed_supervisor?/1)
    |> Enum.count()
  end

  def get_child_pids_for_feed_supervisor(name) do
    Reaper.Registry
    |> Horde.Registry.lookup(name)
    |> Horde.Supervisor.which_children()
    |> Enum.map(fn {_, pid, _, _} -> pid end)
    |> Enum.sort()
  end

  def child_count(module) do
    Reaper.Horde.Supervisor
    |> Horde.Supervisor.which_children()
    |> Enum.filter(&is_feed_supervisor?/1)
    |> Enum.flat_map(&get_supervisor_children/1)
    |> Enum.filter(fn {_, _, _, [mod]} -> mod == module end)
    |> Enum.count()
  end

  def fetch_relevant_messages(dataset_id) do
    @destination_topic
    |> fetch_all_feed_messages()
    |> Enum.filter(fn %{"dataset_id" => id} -> id == dataset_id end)
    |> Enum.map(fn %{"payload" => payload} -> payload end)
  end

  def bypass_file(bypass, file_name) do
    Bypass.stub(bypass, "GET", "/#{file_name}", fn conn ->
      Plug.Conn.resp(
        conn,
        200,
        File.read!("test/support/#{file_name}")
      )
    end)

    bypass
  end

  def fetch_all_feed_messages(topic) do
    Stream.resource(
      fn -> 0 end,
      fn offset ->
        with {:ok, results} <- :brod.fetch(@kafka_endpoint, topic, 0, offset),
             {:kafka_message, current_offset, _headers?, _partition, _key, _body, _ts, _type, _ts_type} <-
               List.last(results) do
          {results, current_offset + 1}
        else
          _ -> {:halt, offset}
        end
      end,
      fn _ -> :unused end
    )
    |> Enum.map(fn {:kafka_message, _offset, _headers?, _partition, _key, body, _ts, _type, _ts_type} ->
      Jason.decode!(body)
    end)
  end

  defp is_feed_supervisor?([{_, _, _, [mod]}]) do
    mod == Reaper.FeedSupervisor
  end

  defp is_feed_supervisor?([]), do: false

  defp get_supervisor_children([{_, pid, _, _}]) do
    Supervisor.which_children(pid)
  end

  defp get_supervisor_children([]), do: []
end
