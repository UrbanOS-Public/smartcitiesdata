defmodule Reaper.AuthRetriever do
  @moduledoc """
  Call the authUrl of a dataset, passing the authHeaders, and returning the response.
  """

  @instance Reaper.Application.instance()

  def retrieve(dataset_id) do
    reaper_config = Brook.get!(@instance, :reaper_config, dataset_id)
    body = Map.get(reaper_config, :authBody, %{}) |> encode_body()
    response = HTTPoison.post!(reaper_config.authUrl, body, evaluate_headers(reaper_config.authHeaders))
    Jason.decode!(response.body)
  end

  defp evaluate_headers(headers) do
    headers
    |> Enum.map(&evaluate_header(&1))
    |> Enum.into(%{})
  end

  defp evaluate_header({key, value}) do
    {key, EEx.eval_string(value, [])}
  end

  defp encode_body(body) when body == %{}, do: ""
  defp encode_body(body), do: Jason.encode!(body)
end
