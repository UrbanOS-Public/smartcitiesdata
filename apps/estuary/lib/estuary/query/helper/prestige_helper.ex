defmodule Estuary.Query.Helper.PrestigeHelper do
  @moduledoc false

  def execute_query_stream(query) do
    with {:ok, data} <-
           create_session()
           |> prestige().stream!(query) do
      {:ok, Stream.flat_map([data], &Prestige.Result.as_maps/1)}
    else
      error -> error
    end
  end

  defp create_session do
    Application.get_env(:prestige, :session_opts)
    |> prestige().new_session()
  end

  defp prestige, do: Application.get_env(:estuary, :prestige, Prestige)
end
