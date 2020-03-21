defmodule Estuary.Query.Helper.PrestigeHelper do
  @moduledoc false

  def execute_query_stream(query) do
    data =
      create_session()
      |> Prestige.stream!(query)
      |> Stream.flat_map(&Prestige.Result.as_maps/1)

    {:ok, data}
  rescue
    error -> {:error, error}
  end

  defp create_session do
    Application.get_env(:prestige, :session_opts)
    |> Prestige.new_session()
  end
end
