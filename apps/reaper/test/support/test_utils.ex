defmodule TestUtils do
  @moduledoc false

  require Elsa.Message
  require Logger
  alias SmartCity.TestDataGenerator, as: TDG

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

  def bypass_file(bypass, file_name) do
    Bypass.stub(bypass, "HEAD", "/#{file_name}", fn conn ->
      Plug.Conn.resp(conn, 200, "")
    end)

    Bypass.stub(bypass, "GET", "/#{file_name}", fn conn ->
      Plug.Conn.resp(
        conn,
        200,
        File.read!("test/support/#{file_name}")
      )
    end)

    bypass
  end

  defp is_feed_supervisor?([{_, _, _, [mod]}]) do
    mod == Reaper.FeedSupervisor
  end

  defp is_feed_supervisor?([]), do: false

  defp get_supervisor_children([{_, pid, _, _}]) do
    Supervisor.which_children(pid)
  end

  defp get_supervisor_children([]), do: []

  def get_dlq_messages_from_kafka(topic, endpoints) do
    topic
    |> fetch_messages(endpoints)
    |> Enum.map(&Jason.decode!(&1, keys: :atoms))
  end

  def get_data_messages_from_kafka(topic, endpoints) do
    topic
    |> fetch_messages(endpoints)
    |> Enum.map(&SmartCity.Data.new/1)
    |> Enum.map(&elem(&1, 1))
    |> Enum.map(&clear_timing/1)
  end

  def fetch_messages(topic, endpoints) do
    case :brod.fetch(endpoints, topic, 0, 0) do
      {:ok, {_offset, messages}} ->
        messages
        |> Enum.map(&Elsa.Message.kafka_message(&1, :value))

      {:error, reason} ->
        Logger.warn("Failed to extract messages: #{inspect(reason)}")
        []
    end
  end

  def create_data(overrides) do
    overrides
    |> TDG.create_data()
    |> clear_timing()
    |> clear_metadata()
  end

  def clear_metadata(%SmartCity.Data{} = data_message) do
    Map.update!(data_message, :_metadata, fn _ -> %{} end)
  end

  def clear_timing(%SmartCity.Data{} = data_message) do
    Map.update!(data_message, :operational, fn _ -> %{timing: []} end)
  end
end
