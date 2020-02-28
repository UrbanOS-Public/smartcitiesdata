defmodule Pipeline.Writer.TableWriter.Helper.PrestigeHelper do
  @moduledoc false

  require Logger

  def execute_query(query) do
    create_session()
    |> Prestige.execute(query)
  rescue
    error -> error
  end

  def execute_async_query(statement) do
    Task.async(fn ->
      try do
        execute_query(statement)
      rescue
        e -> Logger.error("Failed to execute '#{statement}': #{inspect(e)}")
      end
    end)
  end

  def create_session do
    Application.get_env(:prestige, :session_opts)
    |> Prestige.new_session()
  end
end
