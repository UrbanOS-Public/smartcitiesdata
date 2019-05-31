defmodule Andi.LdapUtils do
  @moduledoc """
  Module to help integration with LDAP and consuming/producing its
  distinguished names.
  """

  @doc """
  Takes an LDAP-compatible DN as a keyword list and converts to a
  string acceptable by LDAP systems.
  """
  @spec encode_dn!(keyword()) :: String.t() | none()
  def encode_dn!([{key, _} | _] = kwdn) when is_atom(key) do
    kwdn
    |> Enum.map(fn {k, v} -> "#{k}=#{v}" end)
    |> Enum.join(",")
  end

  @doc """
  Takes an LDAP DN string and breaks it into an Elixir keyword list.
  """
  @spec decode_dn!(String.t()) :: keyword() | none()
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
