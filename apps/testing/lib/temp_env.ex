defmodule Temp.Env do
  @moduledoc """
  Macro for altering application environments at runtime. Useful for
  very targeted tests.
  """
  defmacro modify(entries) do
    quote do
      setup do
        backup =
          unquote(entries)
          |> Enum.map(fn %{app: app} -> app end)
          |> Enum.uniq()
          |> Enum.reduce([], fn app, acc ->
            Keyword.put(acc, app, Application.get_all_env(app))
          end)

        unquote(entries)
        |> Enum.each(fn entry ->
          case entry do
            %{set: value} ->
              Application.put_env(entry.app, entry.key, value)

            %{update: function} ->
              value = Application.get_env(entry.app, entry.key)
              new_value = function.(value || [])
              Application.put_env(entry.app, entry.key, new_value)

            %{delete: true} ->
              Application.delete_env(entry.app, entry.key)
          end
        end)

        on_exit(fn ->
          unquote(entries)
          |> Enum.each(fn %{app: app, key: key} ->
            Application.delete_env(app, key)
          end)
          Enum.each(backup, fn {key, values} -> Application.put_env(key, values, persistent: true) end)
        end)

        :ok
      end
    end
  end
end
