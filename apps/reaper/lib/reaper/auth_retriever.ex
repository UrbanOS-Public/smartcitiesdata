defmodule Reaper.AuthRetriever do
  @moduledoc """
  Call the authUrl of a dataset, passing the authHeaders, and returning the response.
  """
  def retrieve(dataset_id) do
    dataset = Reaper.Persistence.get(dataset_id)
    response = HTTPoison.get!(dataset.authUrl, evaluate_headers(dataset.authHeaders))
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
end
