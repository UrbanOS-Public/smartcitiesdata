defmodule Reaper.AuthRetriever do
  @moduledoc """
  Call the authUrl of a dataset, passing the authHeaders, and returning the response.
  """
  alias Reaper.Cache.AuthCache
  @instance Reaper.Application.instance()

  def retrieve(dataset_id, cache_ttl \\ 10_000) do
    case AuthCache.get(dataset_id) do
      nil -> retrieve_from_url(dataset_id, cache_ttl)
      auth -> auth
    end
  end

  defp retrieve_from_url(dataset_id, cache_ttl) do
    reaper_config = Brook.get!(@instance, :reaper_config, dataset_id)

    body =
      Map.get(reaper_config, :authBody, %{})
      |> evaluate_eex_map()
      |> encode_body()

    headers = evaluate_eex_map(reaper_config.authHeaders)

    case HTTPoison.post(reaper_config.authUrl, body, headers) do
      {:ok, %{status_code: code, body: body}} when code < 400 ->
        AuthCache.put(dataset_id, body, ttl: cache_ttl)
        body

      {:ok, %{status_code: code}} ->
        raise "Unable to retrieve auth credentials for dataset #{dataset_id} with status #{code}"

      error ->
        raise "Unable to retrieve auth credentials for dataset #{dataset_id} with error #{inspect(error)}"
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
