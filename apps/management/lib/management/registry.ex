defmodule Management.Registry do
  @moduledoc """
  Folds helper functions around `Registry` usage into a
  custom `Registry` module.
  """
  defmacro __using__(opts) do
    name = Keyword.fetch!(opts, :name)

    quote location: :keep do
      def child_spec(_init_arg) do
        Supervisor.child_spec({Registry, keys: :unique, name: unquote(name)}, [])
      end

      @spec via(key) :: {:via, Registry, {unquote(name), key}} when key: term
      def via(key) do
        {:via, Registry, {unquote(name), key}}
      end

      @spec registered_processes() :: list
      def registered_processes() do
        Registry.select(unquote(name), [{{:"$1", :_, :_}, [], [:"$1"]}])
      end

      @spec whereis(key :: term) :: pid | :undefined
      def whereis(key) do
        case Registry.lookup(unquote(name), key) do
          [{pid, _}] -> pid
          _ -> :undefined
        end
      end
    end
  end
end
