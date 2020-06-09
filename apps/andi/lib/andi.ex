defmodule Andi do
  @moduledoc """
  Andi keeps the contexts that define your domain
  and business logic.

  Contexts are also responsible for managing your data, regardless
  if it comes from the database, an external API or others.
  """

  defmacro instance_name, do: :andi

  def prestige_opts(), do: Application.get_env(:prestige, :session_opts)
end
