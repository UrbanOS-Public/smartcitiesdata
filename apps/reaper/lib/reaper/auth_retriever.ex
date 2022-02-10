defmodule Reaper.AuthRetriever do
  @moduledoc """
  Call the authUrl of a dataset, passing the authHeaders, and returning the response.
  """
  alias Reaper.Collections.Extractions
  alias Reaper.Cache.AuthCache
  alias Reaper.Util

  def authorize(ingestion_id, url, body, encode_method, headers, cache_ttl) when is_list(headers) do
    authorize(ingestion_id, url, body, encode_method, Enum.into(headers, %{}), cache_ttl)
  end

  def authorize(ingestion_id, url, body, encode_method, headers, cache_ttl) do
    cache_ttl = cache_ttl || 10_000

    complete_headers = headers |> add_content_type(body, encode_method)

    cache_id = hash_config(%{url: url, body: body, headers: complete_headers})

    case AuthCache.get(cache_id) do
      nil ->
        auth = make_auth_request(ingestion_id, url, body, complete_headers)
        AuthCache.put(cache_id, auth, ttl: cache_ttl)
        auth

      auth ->
        auth
    end
  end

  defp hash_config(auth_params_map) do
    json = Jason.encode!(auth_params_map)
    :crypto.hash(:md5, json)
  end

  defp make_auth_request(ingestion_id, url, body, headers) do
    case HTTPoison.post(url, body, headers) do
      {:ok, %{status_code: code, body: body, headers: headers}} when code < 400 ->
        content_encoding = Util.get_header_value(headers, "content-encoding")
        handle_content_encoding(body, content_encoding)

      {:ok, %{status_code: code}} ->
        raise "Unable to retrieve auth credentials for dataset #{ingestion_id} with status #{code}"

      error ->
        raise "Unable to retrieve auth credentials for dataset #{ingestion_id} with error #{inspect(error)}"
    end
  end

  defp handle_content_encoding(body, "gzip") do
    try do
      :zlib.gunzip(body)
    rescue
      _ ->
        reraise("Unable to decompress auth credentials. Payload may be corrupted or not compressed.", __STACKTRACE__)
    end
  end

  defp handle_content_encoding(body, _), do: body

  defp encode_body(body, "json"), do: Jason.encode!(body)
  defp encode_body(body, _), do: URI.encode_query(body)

  defp add_content_type(headers, "", _), do: headers
  defp add_content_type(headers, _body, "json"), do: Map.put(headers, "Content-Type", "application/json")
  defp add_content_type(headers, _body, _), do: Map.put(headers, "Content-Type", "application/x-www-form-urlencoded")
end
