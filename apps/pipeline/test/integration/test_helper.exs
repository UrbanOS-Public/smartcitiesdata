defmodule Pipeline.TestHandler do
  use Elsa.Consumer.MessageHandler
  alias Pipeline.Writer.TableWriter.Helper.PrestigeHelper

  def init(_ \\ []) do
    {:ok, []}
  end

  def handle_messages(messages, state) do
    Registry.put_meta(Pipeline.TestRegistry, :messages, messages)
    {:ack, state}
  end

  def drop_all_tables() do
    {:ok, result} = PrestigeHelper.execute_query("show tables")
    result |> Prestige.Result.as_maps() |> Enum.each(&PrestigeHelper.drop_table/1)
  end
end

ExUnit.start()
