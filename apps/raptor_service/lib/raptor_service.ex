defmodule RaptorService do
  use Properties, otp_app: :raptor_service
  require Logger

  # Deliberately short: this is an internal, low-latency authorization lookup,
  # not a bulk data transfer - previously these calls passed no timeout at all
  # and silently ran on HTTPoison/hackney's own default (recv_timeout ~5s),
  # which held a connection (and the calling process) open for the full 5s on
  # every failure instead of failing fast. These are intentionally shorter
  # than that default, and are not related to the unconnected `httpoison_options`
  # config under `:elastix` (that's the Elasticsearch client, a different library).
  getter(:connect_timeout_ms, generic: true, default: 2_000)
  getter(:recv_timeout_ms, generic: true, default: 3_000)
  getter(:pool_max_connections, generic: true, default: 25)

  # A dedicated, bounded pool for Raptor calls specifically, separate from
  # hackney's shared default pool used by other HTTP clients in the same VM
  # (Elasticsearch, S3, etc). This bounds the blast radius of a degraded
  # Raptor to at most pool_max_connections() held connections, each capped at
  # connect_timeout_ms()/recv_timeout_ms() - so a sustained period of Raptor
  # failures can only ever hold a small, constant, fully-reclaimable amount of
  # memory, and nothing lingers once Raptor recovers or the pool's own
  # checkout timeout fires.
  @pool_name :raptor_http_pool

  @doc """
  Child spec for the dedicated Raptor connection pool, meant to be started
  once at application boot (see DiscoveryApi.Application) so the bounded pool
  exists deterministically before the first request, rather than being
  lazily created on first use with hackney's own (larger, unbounded-timeout)
  defaults.
  """
  def pool_child_spec do
    :hackney_pool.child_spec(@pool_name, max_connections: pool_max_connections(), timeout: connect_timeout_ms())
  end

  # Carries the pool's sizing/timeout directly on every request (not just at
  # pool-start time) so any caller gets the same bounded, fail-fast behavior
  # even if it happens to be the one that lazily creates the pool.
  defp request_options do
    [
      timeout: connect_timeout_ms(),
      recv_timeout: recv_timeout_ms(),
      hackney: [pool: @pool_name, max_connections: pool_max_connections(), timeout: connect_timeout_ms()]
    ]
  end

  def list_groups_by_user(raptor_url, user_id) do
    case HTTPoison.get(list_url_with_user_params(raptor_url, user_id), [], request_options()) do
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
    case HTTPoison.get(list_url_with_dataset_params(raptor_url, dataset_id), [], request_options()) do
      {:ok, %{body: body}} ->
        {:ok, access_groups} = Jason.decode(body)
        %{ access_groups: access_groups["access_groups"] }

      error ->
        Logger.error("Raptor failed to retrieve access groups with error: #{inspect(error)}")
        raise "Access groups cannot be retrieved for dataset #{dataset_id}"
    end
  end

  def list_groups_by_api_key(raptor_url, api_key) do
    case HTTPoison.get(list_url_with_api_key_params(raptor_url, api_key), [], request_options()) do
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
    case HTTPoison.get(raptor_url_with_params(raptor_url, api_key, system_name), [], request_options()) do
      {:ok, %{body: body}} ->
        {:ok, is_authorized} = Jason.decode(body)
        is_authorized["is_authorized"]

      error ->
        Logger.error("Raptor failed to authorize with error: #{inspect(error)}")
        false
    end
  end

  def is_authorized_by_user_id(raptor_url, user_id, system_name) do
    case HTTPoison.get(raptor_url_with_user_params(raptor_url, user_id, system_name), [], request_options()) do
      {:ok, %{body: body}} ->
        {:ok, is_authorized} = Jason.decode(body)
        is_authorized["is_authorized"]

      error ->
        Logger.error("Raptor failed to authorize with error: #{inspect(error)}")
        false
    end
  end

  def regenerate_api_key_for_user(raptor_url, user_id) do
    case HTTPoison.patch(url_for_api_key_regeneration(raptor_url, user_id), '', [], request_options()) do
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
    case HTTPoison.get(url_for_api_key_validation(raptor_url, api_key), [], request_options()) do
      {:ok, %{body: body, status_code: status_code}} when status_code in 200..399 ->
        {:ok, get_user_id_from_response_body(body)}

      {:ok, %{body: body, status_code: status_code}} when status_code == 401 ->
        error_reason = Jason.decode!(body)["message"]

        Logger.error(
          "Raptor failed while attempting to validate api key \"#{api_key}\" with error: #{error_reason}"
        )

        {:error, error_reason, status_code}

      error ->
        Logger.error(
          "Raptor encountered an unknown error while attempting to validate api key \"#{api_key}\": #{inspect(error)}"
        )

        {:error, "Internal Server Error", 500}
    end
  end

  def check_auth0_role(raptor_url, api_key, role) do
    case HTTPoison.get(url_for_checking_role(raptor_url, api_key, role), [], request_options()) do
      {:ok, %{body: body, status_code: status_code}} when status_code in 200..399 ->
        {:ok, Jason.decode!(body)["has_role"]}

      {:ok, %{body: body, status_code: status_code}} ->
        error_reason = Jason.decode!(body)["message"]

        Logger.error(
          "Raptor failed while attempting to validate api key \"#{api_key}\" with error: #{error_reason}"
        )

        {:error, error_reason, status_code}

      error ->
        Logger.error(
          "Raptor encountered an unknown error while attempting to validate api key \"#{api_key}\": #{inspect(error)}"
        )

        {:error, "Internal Server Error", 500}
    end
  end

  defp url_for_api_key_regeneration(raptor_url, user_id) do
    "#{raptor_url}/regenerateApiKey?user_id=#{URI.encode_www_form(user_id)}"
  end

  defp url_for_api_key_validation(raptor_url, api_key) do
    "#{raptor_url}/getUserIdFromApiKey?api_key=#{URI.encode_www_form(api_key)}"
  end

  defp url_for_checking_role(raptor_url, api_key, role) do
    "#{raptor_url}/checkRole?api_key=#{URI.encode_www_form(api_key)}&role=#{URI.encode_www_form(role)}"
  end

  defp list_url_with_api_key_params(raptor_url, nil) do
    "#{raptor_url}/listAccessGroups"
  end

  defp list_url_with_api_key_params(raptor_url, api_key) do
    "#{raptor_url}/listAccessGroups?api_key=#{URI.encode_www_form(api_key)}"
  end

  defp list_url_with_user_params(raptor_url, nil) do
    "#{raptor_url}/listAccessGroups"
  end

  defp list_url_with_user_params(raptor_url, user_id) do
    "#{raptor_url}/listAccessGroups?user_id=#{URI.encode_www_form(user_id)}"
  end

  defp list_url_with_dataset_params(raptor_url, nil) do
    "#{raptor_url}/listAccessGroups"
  end

  defp list_url_with_dataset_params(raptor_url, dataset_id) do
    "#{raptor_url}/listAccessGroups?dataset_id=#{URI.encode_www_form(dataset_id)}"
  end

  defp raptor_url_with_params(raptor_url, nil, nil) do
    "#{raptor_url}/authorize"
  end

  defp raptor_url_with_params(raptor_url, api_key, nil) do
    "#{raptor_url}/authorize?apiKey=#{URI.encode_www_form(api_key)}"
  end

  defp raptor_url_with_params(raptor_url, nil, system_name) do
    "#{raptor_url}/authorize?systemName=#{URI.encode_www_form(system_name)}"
  end

  defp raptor_url_with_params(raptor_url, api_key, system_name) do
    "#{raptor_url}/authorize?apiKey=#{URI.encode_www_form(api_key)}&systemName=#{URI.encode_www_form(system_name)}"
  end

  defp raptor_url_with_user_params(raptor_url, nil, nil) do
    "#{raptor_url}/authorize"
  end

  defp raptor_url_with_user_params(raptor_url, user_id, nil) do
    "#{raptor_url}/authorize?auth0_user=#{URI.encode_www_form(user_id)}"
  end

  defp raptor_url_with_user_params(raptor_url, nil, system_name) do
    "#{raptor_url}/authorize?systemName=#{URI.encode_www_form(system_name)}"
  end

  defp raptor_url_with_user_params(raptor_url, user_id, system_name) do
    "#{raptor_url}/authorize?auth0_user=#{URI.encode_www_form(user_id)}&systemName=#{URI.encode_www_form(system_name)}"
  end

  defp get_user_id_from_response_body(response_body) do
    Jason.decode!(response_body)["user_id"]
  end
end
