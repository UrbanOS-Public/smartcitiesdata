defimpl Brook.Deserializer.Protocol, for: DiscoveryApi.Data.Model do
  # sobelow_skip ["DOS.StringToAtom"]
  def deserialize(_struct, data) do
    model = struct(DiscoveryApi.Data.Model, data)

    org_with_atom_keys =
      model.organizationDetails
      |> Enum.map(fn {k, v} -> {String.to_atom(k), v} end)
      |> Map.new()

    org_details = struct(DiscoveryApi.Data.OrganizationDetails, org_with_atom_keys)
    {:ok, Map.put(model, :organizationDetails, org_details)}
  end
end
