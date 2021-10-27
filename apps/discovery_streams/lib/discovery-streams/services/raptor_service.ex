defmodule DiscoveryStreams.Services.RaptorService do

  use Properties, otp_app: :discovery_streams
  require Logger

  getter(:raptor, generic: true)

  def is_authorized(api_key, system_name) do
    raptor_url = Keyword.fetch!(raptor(), :url)
    case HTTPoison.get(raptor_url_with_params(raptor_url, api_key, system_name)) do
      {:ok, %{body: body}} ->
        body
        {:ok, is_authorized} = Jason.decode(body)
        is_authorized["is_authorized"]
      error ->
        Logger.error("Raptor failed to authorize with error: #{error}")
        false
    end
  end

  defp raptor_url_with_params(raptor_url, nil, nil) do
    "#{raptor_url}"
  end

  defp raptor_url_with_params(raptor_url, api_key, nil) do
    "#{raptor_url}?apiKey=#{api_key}"
  end

  defp raptor_url_with_params(raptor_url, nil, system_name) do
    "#{raptor_url}?systemName=#{system_name}"
  end

  defp raptor_url_with_params(raptor_url, api_key, system_name) do
    "#{raptor_url}?apiKey=#{api_key}&systemName=#{system_name}"
  end
end
