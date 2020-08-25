defmodule Management.ViewState do
  @moduledoc """
  View state management behaviour and default implementation on a per-collection
  basis. `ViewState` collections should track only one type of object.

  ## Configuration

  Configure `ViewState` with `use/2` macro.

  * `instance` - Brook instance name. See `Brook.instance()` for more info.
  * `collection` - Name for object grouping. See `Brook.view_collection()` for more info.
  """

  @callback collection() :: Brook.view_collection()
  @callback persist(Brook.view_key(), map) :: :ok
  @callback get(Brook.view_key()) :: {:ok, nil | map} | {:error, term}
  @callback get_all() :: {:ok, [Brook.view_value()]} | {:error, term}
  @callback delete(Brook.view_key()) :: :ok

  defmacro __using__(opts) do
    instance = Keyword.fetch!(opts, :instance)
    collection = Keyword.fetch!(opts, :collection)

    quote location: :keep do
      @behaviour Management.ViewState

      @impl true
      def collection do
        unquote(collection)
      end

      @impl true
      def persist(key, object) do
        unquote(collection)
        |> Brook.ViewState.merge(key, object)
      end

      @impl true
      def get(key) do
        unquote(instance)
        |> Brook.get!(unquote(collection), key)
        |> Ok.ok()
      catch
        _, reason -> {:error, reason}
      end

      @impl true
      def get_all do
        unquote(instance)
        |> Brook.get_all_values(unquote(collection))
        |> Ok.map(fn
          nil -> []
          x -> x
        end)
      end

      @impl true
      def delete(key) do
        unquote(collection)
        |> Brook.ViewState.delete(key)
      end

      defoverridable Management.ViewState
    end
  end
end
