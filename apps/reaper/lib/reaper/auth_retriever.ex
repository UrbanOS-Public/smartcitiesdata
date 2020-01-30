defmodule Reaper.AuthRetriever do
  @moduledoc """
  Call the authUrl of a dataset, passing the authHeaders, and returning the response.
  """

  @instance Reaper.Application.instance()

  def retrieve(dataset_id) do
    reaper_config = Brook.get!(@instance, :reaper_config, dataset_id)

    body =
      Map.get(reaper_config, :authBody, %{})
      |> evaluate_eex_map()
      |> encode_body()

    headers = evaluate_eex_map(reaper_config.authHeaders)

    response = HTTPoison.post!(reaper_config.authUrl, body, headers)
    Jason.decode!(response.body)
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
