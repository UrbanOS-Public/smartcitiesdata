defmodule Reaper.AuthRetriever do
  @moduledoc """
  Call the authUrl of a dataset, passing the authHeaders, and returning the response.
  """
  alias Reaper.Cache.AuthCache
  @instance Reaper.Application.instance()

  def retrieve(dataset_id, cache_ttl \\ 10_000) do
    reaper_config = Brook.get!(@instance, :reaper_config, dataset_id)
    id = hash_config(reaper_config)
    case AuthCache.get(id) do
      nil -> retrieve_from_url(reaper_config, id, cache_ttl)
      auth -> auth
    end
  end

  def hash_config(reaper_config) do
    plain_text = Jason.encode!(reaper_config)
    :crypto.hash(:md5, plain_text)
  end

  defp retrieve_from_url(reaper_config, cache_id, cache_ttl) do
    body =
      Map.get(reaper_config, :authBody, %{})
      |> evaluate_eex_map()
      |> encode_body()

    headers = evaluate_eex_map(reaper_config.authHeaders)

    auth = make_auth_request(reaper_config, body, headers)
    AuthCache.put(cache_id, auth, ttl: cache_ttl)
    auth
  end

  defp make_auth_request(reaper_config, body, headers) do
    case HTTPoison.post(reaper_config.authUrl, body, headers) do
      {:ok, %{status_code: code, body: body}} when code < 400 ->
        body

      {:ok, %{status_code: code}} ->
        raise "Unable to retrieve auth credentials for dataset #{reaper_config.dataset_id} with status #{code}"

      error ->
        raise "Unable to retrieve auth credentials for dataset #{reaper_config.dataset_id} with error #{inspect(error)}"
    end
  end

  defp evaluate_eex_map(map) do
    map
    |> Enum.map(&evaluate_eex(&1))
    |> Enum.into(%{})
  end

  defp evaluate_eex({key, value}) do
    {key, EEx.eval_string(value, [])}
  end

  defp encode_body(body), do: URI.encode_query(body)
end
