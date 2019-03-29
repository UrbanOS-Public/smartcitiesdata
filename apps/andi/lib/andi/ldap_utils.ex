defmodule Andi.LdapUtils do
  @moduledoc """
  Module to help integration with LDAP and consuming/producing its
  distinguished names.
  """

  @spec encode_dn!(keyword()) :: String.t()
  def encode_dn!([{key, _} | _] = kwdn) when is_atom(key) do
    kwdn
    |> Enum.map(fn {k, v} -> "#{k}=#{v}" end)
    |> Enum.join(",")
  end

  @spec decode_dn!(String.t()) :: keyword()
  def decode_dn!(dn) do
    dn
    |> String.split(",")
    |> Enum.map(&keyword_tuple/1)
  end

  defp keyword_tuple(str) do
    case String.split(str, "=") do
      [key, value] -> {String.to_atom(key), value}
      other -> raise "invalid dn element: #{inspect(other)}"
    end
  end
end
