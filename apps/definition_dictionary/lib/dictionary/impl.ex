defmodule Dictionary.Impl do
  @moduledoc false
  require Logger
  use JsonSerde, alias: "dictionary"

  @behaviour Access

  @type t :: %__MODULE__{
          by_type: %{module => [String.t()]},
          by_name: map,
          ordered: list,
          size: integer
        }

  @type field :: term

  defstruct by_type: %{},
            by_name: %{},
            ordered: [],
            size: 0

  @spec from_list(list) :: t
  def from_list(list) do
    Enum.into(list, %__MODULE__{})
  end

  @spec get_field(t, String.t()) :: field
  def get_field(%__MODULE__{by_name: by_name}, name) do
    case Map.get(by_name, name) do
      {_, field} -> field
      result -> result
    end
  end

  @spec get_by_type(t | [Dictionary.Type.Normalizer.t()], module) :: list(list(String.t()))
  def get_by_type(dictionary, module) when is_list(dictionary) do
    Logger.warn(fn -> "#{__MODULE__}.get_by_type/2: Received list #{inspect(dictionary)}" end)

    from_list(dictionary)
    |> get_by_type(module)
  end

  def get_by_type(%__MODULE__{by_type: by_type, ordered: ordered}, type) do
    local =
      Map.get(by_type, type, [])
      |> Enum.map(&List.wrap/1)

    children =
      ordered
      |> Enum.map(&collapse_list/1)
      |> Enum.filter(&Map.has_key?(&1, :dictionary))
      |> Enum.reduce([], fn field, acc ->
        sub_fields =
          get_by_type(field.dictionary, type)
          |> Enum.map(fn result ->
            [field.name | result]
          end)

        acc ++ sub_fields
      end)

    local ++ children
  end

  @spec update_field(t, String.t(), field | (field -> field)) :: t
  def update_field(%__MODULE__{} = dictionary, _name, nil) do
    dictionary
  end

  def update_field(%__MODULE__{} = dictionary, name, update_function)
      when is_function(update_function, 1) do
    new_field =
      get_field(dictionary, name)
      |> update_function.()

    update_field(dictionary, name, new_field)
  end

  def update_field(%__MODULE__{} = dictionary, name, new_field) do
    case Map.get(dictionary.by_name, name) do
      {index, _} ->
        List.replace_at(dictionary.ordered, index, new_field)

      nil ->
        dictionary.ordered ++ [new_field]
    end
    |> from_list()
  end

  @spec delete_field(t, String.t()) :: t
  def delete_field(%__MODULE__{} = dictionary, name) do
    case Map.get(dictionary.by_name, name) do
      {index, _field} ->
        dictionary.ordered
        |> List.delete_at(index)
        |> from_list()

      _ ->
        dictionary
    end
  end

  @impl Access
  def fetch(term, key) do
    case get_field(term, key) do
      nil -> :error
      value -> Ok.ok(value)
    end
  end

  @impl Access
  def get_and_update(data, key, function) do
    field = get_field(data, key)

    case function.(field) do
      {get_value, update_value} ->
        {get_value, update_field(data, key, update_value)}

      :pop ->
        {field, delete_field(data, key)}
    end
  end

  @impl Access
  def pop(data, key) do
    field = get_field(data, key)
    {field, delete_field(data, key)}
  end

  @spec validate_field(
          t,
          String.t() | [String.t()] | [Dictionary.Access.access_fun()],
          module
        ) :: :ok | {:error, term}
  def validate_field(dictionary, path, type) do
    value = get_in(dictionary, path)

    case struct?(type, value) do
      true ->
        :ok

      false ->
        simple_type = to_string(type) |> String.split(".") |> List.last() |> String.downcase()
        reason = :"invalid_#{simple_type}"
        {:error, reason}
    end
  end

  defp struct?(struct_module, %struct_module{}), do: true
  defp struct?(_, _), do: false

  defp collapse_list(%{name: name, item_type: %{dictionary: dictionary}}) do
    apply(Dictionary.Type.Map, :new!, [[name: name, dictionary: dictionary]])
  end

  defp collapse_list(o), do: o

  defimpl Collectable, for: __MODULE__ do
    def into(original) do
      collector_fun = fn
        dictionary, {:cont, %type{} = elem} ->
          Map.update!(dictionary, :by_name, fn map ->
            Map.put(map, elem.name, {dictionary.size, elem})
          end)
          |> Map.update!(:by_type, fn map ->
            Map.update(map, type, [elem.name], fn l -> [elem.name | l] end)
          end)
          |> Map.update!(:ordered, fn list -> [elem | list] end)
          |> Map.update!(:size, fn size -> size + 1 end)

        dictionary, :done ->
          Map.update!(dictionary, :ordered, fn list -> Enum.reverse(list) end)

        _dictionary, :halt ->
          :ok
      end

      {original, collector_fun}
    end
  end

  defimpl Enumerable, for: __MODULE__ do
    def reduce(%{ordered: ordered}, acc, fun) do
      Enumerable.reduce(ordered, acc, fun)
    end

    def count(%{ordered: ordered}) do
      Enumerable.count(ordered)
    end

    def member?(%{ordered: ordered}, element) do
      Enumerable.member?(ordered, element)
    end

    def slice(%{ordered: ordered}) do
      Enumerable.slice(ordered)
    end
  end

  defimpl JsonSerde.Serializer do
    def serialize(%{ordered: ordered}) do
      with {:ok, fields} <- JsonSerde.Serializer.serialize(ordered) do
        {:ok,
         %{
           JsonSerde.data_type_key() => "dictionary",
           "fields" => fields
         }}
      end
    end
  end

  defimpl JsonSerde.Deserializer do
    def deserialize(_, %{"fields" => fields}) do
      with {:ok, types} <- JsonSerde.Deserializer.deserialize(fields, fields) do
        {:ok, Dictionary.from_list(types)}
      end
    end
  end
end
