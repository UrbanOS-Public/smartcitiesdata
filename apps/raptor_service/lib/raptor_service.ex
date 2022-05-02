defmodule RaptorService do
  use Properties, otp_app: :raptor_service
  require Logger

  def list_access_groups_by_user(raptor_url, user_id) do
    case HTTPoison.get(list_url_with_user_params(raptor_url, user_id)) do
      {:ok, %{body: body}} ->
        {:ok, access_groups} = Jason.decode(body)
        access_groups["access_groups"]

      error ->
        Logger.error("Raptor failed to retrieve access groups with error: #{inspect(error)}")
        false
    end

  end

  def list_access_groups_by_dataset(raptor_url, dataset_id) do
    case HTTPoison.get(list_url_with_dataset_params(raptor_url, dataset_id)) do
      {:ok, %{body: body}} ->
        {:ok, access_groups} = Jason.decode(body)
        access_groups["access_groups"]

      error ->
        Logger.error("Raptor failed to retrieve access groups with error: #{inspect(error)}")
        false
    end
  end

  def list_access_groups_by_api_key(raptor_url, api_key) do
    case HTTPoison.get(list_url_with_api_key_params(raptor_url, api_key)) do
      {:ok, %{body: body}} ->
        {:ok, access_groups} = Jason.decode(body)
        access_groups["access_groups"]

      error ->
        Logger.error("Raptor failed to retrieve access groups with error: #{inspect(error)}")
        false
    end
  end


  def is_authorized(raptor_url, api_key, system_name) do
    case HTTPoison.get(raptor_url_with_params(raptor_url, api_key, system_name)) do
      {:ok, %{body: body}} ->
        {:ok, is_authorized} = Jason.decode(body)
        is_authorized["is_authorized"]

      error ->
        Logger.error("Raptor failed to authorize with error: #{inspect(error)}")
        false
    end
  end

  def is_authorized_by_user_id(raptor_url, user_id, system_name) do
    case HTTPoison.get(raptor_url_with_user_params(raptor_url, user_id, system_name)) do
      {:ok, %{body: body}} ->
        {:ok, is_authorized} = Jason.decode(body)
        is_authorized["is_authorized"]

      error ->
        Logger.error("Raptor failed to authorize with error: #{inspect(error)}")
        false
    end
  end

  defp list_url_with_api_key_params(raptor_url, nil) do
    "#{raptor_url}/listAccessGroups"
  end

  defp list_url_with_api_key_params(raptor_url, api_key) do
    "#{raptor_url}/listAccessGroups?api_key=#{api_key}"
  end

  defp list_url_with_user_params(raptor_url, nil) do
    "#{raptor_url}/listAccessGroups"
  end

  defp list_url_with_user_params(raptor_url, user_id) do
    "#{raptor_url}/listAccessGroups?user_id=#{user_id}"
  end

  defp list_url_with_dataset_params(raptor_url, nil) do
    "#{raptor_url}/listAccessGroups"
  end

  defp list_url_with_dataset_params(raptor_url, dataset_id) do
    "#{raptor_url}/listAccessGroups?dataset_id=#{dataset_id}"
  end

  defp raptor_url_with_params(raptor_url, nil, nil) do
    "#{raptor_url}/authorize"
  end

  defp raptor_url_with_params(raptor_url, api_key, nil) do
    "#{raptor_url}/authorize?apiKey=#{api_key}"
  end

  defp raptor_url_with_params(raptor_url, nil, system_name) do
    "#{raptor_url}/authorize?systemName=#{system_name}"
  end

  defp raptor_url_with_params(raptor_url, api_key, system_name) do
    "#{raptor_url}/authorize?apiKey=#{api_key}&systemName=#{system_name}"
  end

  defp raptor_url_with_user_params(raptor_url, nil, nil) do
    "#{raptor_url}/authorize"
  end

  defp raptor_url_with_user_params(raptor_url, user_id, nil) do
    "#{raptor_url}/authorize?auth0_user=#{user_id}"
  end

  defp raptor_url_with_user_params(raptor_url, nil, system_name) do
    "#{raptor_url}/authorize?systemName=#{system_name}"
  end

  defp raptor_url_with_user_params(raptor_url, user_id, system_name) do
    "#{raptor_url}/authorize?auth0_user=#{user_id}&systemName=#{system_name}"
  end
end
