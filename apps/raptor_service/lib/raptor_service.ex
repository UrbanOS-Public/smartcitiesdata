defmodule RaptorService do
  use Properties, otp_app: :raptor_service
  require Logger

  def list_groups_by_user(raptor_url, user_id) do
    case HTTPoison.get(list_url_with_user_params(raptor_url, user_id)) do
      {:ok, %{body: body}} ->
        {:ok, groups} = Jason.decode(body)
        %{
          access_groups: groups["access_groups"],
          organizations: groups["organizations"]
        }

      error ->
        Logger.error("Raptor failed to retrieve access groups with error: #{inspect(error)}")
        raise "Access groups cannot be retrieved for user #{user_id}"
    end

  end

  def list_access_groups_by_dataset(raptor_url, dataset_id) do
    case HTTPoison.get(list_url_with_dataset_params(raptor_url, dataset_id)) do
      {:ok, %{body: body}} ->
        {:ok, access_groups} = Jason.decode(body)
        %{ access_groups: access_groups["access_groups"] }

      error ->
        Logger.error("Raptor failed to retrieve access groups with error: #{inspect(error)}")
        raise "Access groups cannot be retrieved for dataset #{dataset_id}"
    end
  end

  def list_groups_by_api_key(raptor_url, api_key) do
    case HTTPoison.get(list_url_with_api_key_params(raptor_url, api_key)) do
      {:ok, %{body: body}} ->
        {:ok, groups} = Jason.decode(body)
        %{
          access_groups: groups["access_groups"],
          organizations: groups["organizations"]
        }

      error ->
        Logger.error("Raptor failed to retrieve access groups with error: #{inspect(error)}")
        raise "Access groups cannot be retrieved for the provided api key"
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

  def regenerate_api_key_for_user(raptor_url, user_id) do
    case HTTPoison.patch(url_for_api_key_regeneration(raptor_url, user_id), '') do
      {:ok, %{body: body, status_code: status_code}} ->
        if (status_code >= 400) do
          {:error, body}
        else
          {:ok, apiKey} = Jason.decode(body)
        end

      error ->
        Logger.error("Raptor failed to regenerate api key with error: #{inspect(error)}")
        "Something went wrong"
    end
  end

  def get_user_id_from_api_key(raptor_url, api_key) do
    case HTTPoison.get(url_for_api_key_validation(raptor_url, api_key)) do
      {:ok, %{body: body, status_code: status_code}} when status_code in 200..399 ->
        {:ok, get_user_id_from_response_body(body)}

      {:ok, %{body: body, status_code: status_code}} when status_code == 401 ->
        error_reason = Jason.decode!(body)["message"]
        Logger.error("Raptor failed while attempting to validate api key with error: #{error_reason}")
        {:error, error_reason, status_code}

      _error ->
        Logger.error("Raptor encountered an unknown error while attempting to validate api key")
        {:error, "Internal Server Error", 500}
    end
  end

  def check_auth0_role(raptor_url, api_key, role) do
    case HTTPoison.get(url_for_checking_role(raptor_url, api_key, role) |> IO.inspect(label: "RYAN - URL")) do
      {:ok, %{body: body, status_code: status_code}} when status_code in 200..399 ->
        {:ok, Jason.decode!(body)["has_role"]}

      {:ok, %{body: body, status_code: status_code}} ->
        error_reason = Jason.decode!(body)["message"]
        Logger.error("Raptor failed while attempting to validate api key with error: #{error_reason}")
        {:error, error_reason, status_code}

      _error ->
        Logger.error("Raptor encountered an unknown error while attempting to validate api key: #{inspect(_error)}")
        {:error, "Internal Server Error", 500}
    end
  end

  defp url_for_api_key_regeneration(raptor_url, user_id) do
    "#{raptor_url}/regenerateApiKey?user_id=#{user_id}"
  end

  defp url_for_api_key_validation(raptor_url, api_key) do
    "#{raptor_url}/getUserIdFromApiKey?api_key=#{api_key}"
  end

  defp url_for_checking_role(raptor_url, api_key, role) do
    "#{raptor_url}/api/checkRole?api_key=#{api_key}&role=#{role}"
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

  defp get_user_id_from_response_body(response_body) do
    Jason.decode!(response_body)["user_id"]
  end
end
