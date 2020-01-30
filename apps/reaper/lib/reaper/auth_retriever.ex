defmodule Reaper.AuthRetriever do
  @moduledoc """
  Call the authUrl of a dataset, passing the authHeaders, and returning the response.
  """
  alias Reaper.Collections.Extractions
  alias Reaper.Cache.AuthCache

  def retrieve(dataset_id, cache_ttl \\ 10_000) do
    dataset = Extractions.get_dataset!(dataset_id)
    id = hash_config(dataset)

    case AuthCache.get(id) do
      nil -> retrieve_from_url(dataset, id, cache_ttl)
      auth -> auth
    end
  end

  defp hash_config(dataset) do
    json = Jason.encode!(dataset)
    :crypto.hash(:md5, json)
  end

  defp retrieve_from_url(dataset, cache_id, cache_ttl) do
    body =
      get_in(dataset, [:technical, :authBody])
      |> evaluate_eex_map()
      |> encode_body()

    # TODO: only add content type header if authBody has stuff in it
    headers =
      evaluate_eex_map(dataset.technical.authHeaders) |> Map.put("Content-Type", "application/x-www-form-urlencoded")

    auth = make_auth_request(dataset, body, headers)
    AuthCache.put(cache_id, auth, ttl: cache_ttl)
    auth
  end

  defp make_auth_request(dataset, body, headers) do
    case HTTPoison.post(dataset.technical.authUrl, body, headers) do
      {:ok, %{status_code: code, body: body}} when code < 400 ->
        body

      {:ok, %{status_code: code}} ->
        raise "Unable to retrieve auth credentials for dataset #{dataset.id} with status #{code}"

      error ->
        raise "Unable to retrieve auth credentials for dataset #{dataset.id} with error #{inspect(error)}"
    end
  end

  defp evaluate_eex_map(nil), do: %{}

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
