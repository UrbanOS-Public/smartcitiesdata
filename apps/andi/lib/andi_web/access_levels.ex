defmodule AndiWeb.AccessLevels do
  @moduledoc """
  Helpers for more easily defining access levels that actions support
  """

  defmacro access_levels(opts \\ []) do
    quote do
      def access_levels_supported(action) do
        action_levels = unquote(opts)

        Keyword.get(action_levels, action, [])
      end
    end
  end
end
