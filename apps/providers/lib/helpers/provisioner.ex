defmodule Providers.Helpers.Provisioner do
  def provision(map) do
    map
    |> Enum.map(&run_if_provider/1)
    |> Enum.into(%{})
  end

  def run_if_provider({key, %{provider: _, version: _} = provider}) do
    {key, run_if_provider(provider)}
  end

  def run_if_provider(%{provider: provider_name, version: version} = provider) do
    provider_opts = Map.get(provider, :opts, [])
    apply(String.to_existing_atom("Elixir.Providers.#{provider_name}"), :provide, [version, provider_opts])
  end

  def run_if_provider({key, value}) when is_map(value), do: {key, provision(value)}
  def run_if_provider(value) when is_map(value), do: provision(value)
  def run_if_provider({key, value}) when is_list(value), do: {key, Enum.map(value, &run_if_provider/1)}

  def run_if_provider(not_provider), do: not_provider |> IO.inspect()
end
