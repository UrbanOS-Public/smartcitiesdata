defmodule AndiWeb.AccessLevels do
  @moduledoc """
  Helpers for more easily defining access levels that actions support
  """

  defmacro access_levels(opts \\ []) do
    quote do
      def access_levels_supported(conn, action) do
        action_levels = unquote(opts)

        Keyword.get(action_levels, action, [])
        |> AndiWeb.AccessLevels.maybe_run_lambdas(conn)
      end
    end
  end

  def maybe_run_lambdas(levels, _conn) when is_list(levels), do: levels
  def maybe_run_lambdas(levels, conn), do: levels.(conn)
end
