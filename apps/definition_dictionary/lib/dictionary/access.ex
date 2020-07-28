defmodule Dictionary.Access do
  @moduledoc false

  @type access_fun :: Access.access_fun(data :: struct | map, get_value :: term())

  @type opts :: [
          spread: boolean
        ]

  @spec to_access_path(String.t() | [String.t()], opts) :: [access_fun]
  def to_access_path(input, opts \\ []) do
    input
    |> List.wrap()
    |> Enum.map(&key(&1, nil, opts))
  end

  @spec key(term, term, opts) :: access_fun
  def key(key, default \\ nil, opts \\ []) do
    &access_fun(key, default, &1, &2, &3, opts)
  end

  defp access_fun(key, default, :get, %module{} = data, next, _opts) do
    case module.fetch(data, key) do
      {:ok, value} -> next.(value)
      :error -> next.(default)
    end
  end

  defp access_fun(key, default, :get, list, next, opts) when is_list(list) do
    Enum.map(list, &access_fun(key, default, :get, &1, next, opts))
  end

  defp access_fun(key, default, :get, data, next, _opts) do
    next.(Map.get(data, key, default))
  end

  defp access_fun(key, _default, :get_and_update, %module{} = data, next, _opts) do
    module.get_and_update(data, key, next)
  end

  defp access_fun(key, default, :get_and_update, list, next, opts) when is_list(list) do
    spread? = Keyword.get(opts, :spread, false)

    {gets, updates} =
      Enum.with_index(list)
      |> Enum.map(fn {entry, index} ->
        wrapper = fn value ->
          with {get_value, update_value} <- next.(value) do
            spread_if_spreadable(get_value, update_value, index, spread?)
          end
        end

        access_fun(key, default, :get_and_update, entry, wrapper, opts)
      end)
      |> Enum.reduce({[], []}, fn {get, update}, {get_acc, update_acc} ->
        {[get | get_acc], [update | update_acc]}
      end)

    {Enum.reverse(gets), Enum.reverse(updates)}
  end

  defp access_fun(key, default, :get_and_update, data, next, _opts) do
    value = Map.get(data, key, default)

    case next.(value) do
      {get, update} -> {get, Map.put(data, key, update)}
      :pop -> {value, Map.delete(data, key)}
    end
  end

  defp spread_if_spreadable(value, update, index, spread?) do
    case is_list(update) && spread? do
      true -> {value, Enum.at(update, index)}
      false -> {value, update}
    end
  end
end
