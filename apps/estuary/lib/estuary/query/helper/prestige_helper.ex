defmodule Estuary.Query.Helper.PrestigeHelper do
  @moduledoc false

  def create_session do
    Application.get_env(:prestige, :session_opts)
    |> Prestige.new_session()
  end
end
