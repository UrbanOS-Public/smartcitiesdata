defimpl Brook.Serializer.Protocol, for: MapSet do
  def serialize(map_set) do
    {:ok,
     %{
       Brook.Serializer.struct_key() => MapSet,
       "values" => MapSet.to_list(map_set)
     }
    }
  end
end

defimpl Brook.Deserializer.Protocol, for: MapSet do
  def deserialize(_, %{values: values}) do
    {:ok, MapSet.new(values)}
  end
end

