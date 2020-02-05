defmodule Estuary.Query.Helper.PrestigeHelper do
  @moduledoc false

  def execute_query(query) do
    data =
      create_session()
      |> Prestige.query!(query)
      |> Prestige.Result.as_maps()

    {:ok, data}
  rescue
    error -> {:error, error}
  end

  defp create_session do
    Application.get_env(:prestige, :session_opts)
    |> Prestige.new_session()
  end
end
