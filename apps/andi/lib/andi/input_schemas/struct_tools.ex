defmodule Andi.InputSchemas.StructTools do
  @moduledoc false

  alias Ecto.Changeset

  def to_map(%_{} = struct) do
    struct
    |> struct_to_map()
    |> to_map()
  end

  def to_map(map) when is_map(map) do
    map
    |> Enum.map(fn {k, v} ->
      {k, to_map(v)}
    end)
    |> Map.new()
  end

  def to_map(value) when is_binary(value) do
    value
  end

  def to_map(list) when is_list(list) do
    list
    |> Enum.map(&to_map/1)
  end

  def to_map(value) do
    value
  end

  def preload(nil, _fields), do: nil

  def preload(list, fields) when is_list(list) do
    Enum.map(list, &preload(&1, fields)) |> sort_if_sequenced()
  end

  def preload(%struct_type{} = struct, fields) do
    preloaded =
      Andi.Repo.preload(struct, fields)
      |> Map.from_struct()
      |> Enum.map(fn
        {k, []} ->
          {k, []}

        {k, nil} ->
          {k, nil}

        {k, v} when is_list(v) ->
          case k in fields do
            true ->
              [%v_type{} | _] = v
              {k, v_type.preload(v)}

            false ->
              {k, v}
          end

        {k, v} ->
          case k in fields do
            true ->
              %v_type{} = v
              {k, v_type.preload(v)}

            false ->
              {k, v}
          end
      end)
      |> Enum.reject(fn {_k, v} ->
        is_nil(v)
      end)

    struct(struct_type, preloaded)
  end

  def sort_if_sequenced([%{sequence: _sequence} | _] = list) do
    Enum.sort_by(list, &Map.get(&1, :sequence))
  end

  def sort_if_sequenced(list), do: list

  def struct_to_map(struct) do
    waste_fields = [:__meta__]

    struct
    |> Map.from_struct()
    |> Map.drop(waste_fields)
    |> Enum.reject(fn
      {_k, %Ecto.Association.NotLoaded{}} -> true
      {_k, v} -> is_nil(v)
    end)
    |> Map.new()
  end

  def safe_from_struct(list) when is_list(list) do
    Enum.map(list, &safe_from_struct/1)
  end

  def safe_from_struct(%_{} = struct), do: Map.from_struct(struct)
  def safe_from_struct(map), do: map

  def ensure_id(%Ecto.Changeset{} = changeset, changes) do
    case Changeset.fetch_field(changeset, :id) do
      {_, _id} -> changes
      :error -> Map.put_new(changes, :id, Ecto.UUID.generate())
    end
  end

  def ensure_id(struct, changes) do
    if struct[:id] do
      changes
    else
      Map.put_new(changes, :id, Ecto.UUID.generate())
      |> AtomicMap.convert(safe: false, underscore: false)
    end
  end
end
