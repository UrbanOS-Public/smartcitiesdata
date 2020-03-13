defmodule Providers.Helpers.Provisioner do
  def provision(map) when is_map(map) do
    map
    |> Enum.map(fn {key, value} -> {key, run_if_provider(value)} end)
    |> Enum.into(%{})
  end

  def provision(list) when is_list(list) do
    Enum.map(list, &run_if_provider/1)
  end

  defp run_if_provider(%{provider: provider_name, version: version} = provider) do
    provider_opts = Map.get(provider, :opts, [])
    apply(provider_module(provider_name), :provide, [version, provider_opts])
  end

  defp run_if_provider(value) when is_map(value) or is_list(value), do: provision(value)

  defp run_if_provider(not_provider), do: not_provider

  defp provider_module(provider_name), do: String.to_existing_atom("Elixir.Providers.#{provider_name}")
end
