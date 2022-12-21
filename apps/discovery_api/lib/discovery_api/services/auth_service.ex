defmodule DiscoveryApi.Services.AuthService do
  @moduledoc """
  Interface for calling remote services for auth.
  """
  require Logger
  import SmartCity.Event, only: [user_login: 0]
  alias DiscoveryApi.Services.AuthService
  alias DiscoveryApi.Schemas.Users
  alias DiscoveryApiWeb.Auth.TokenHandler

  @instance_name DiscoveryApi.instance_name()

  def create_logged_in_user(conn) do
    with {:ok, user_info} <- get_user_info(Guardian.Plug.current_token(conn)),
         {:ok, email} <- Map.fetch(user_info, "email"),
         {:ok, name} <- Map.fetch(user_info, "name"),
         subject_id <- Guardian.Plug.current_claims(conn)["sub"],
         {:ok, user} <- Users.create_or_update(subject_id, %{email: email, name: name}) do
      {:ok, smrt_user} = SmartCity.User.new(%{subject_id: subject_id, email: email, name: name})

      Brook.Event.send(@instance_name, user_login(), __MODULE__, smrt_user)

      {:ok, Guardian.Plug.put_current_resource(conn, user)}
    else
      error ->
        case error do
          {:error, %Jason.DecodeError{data: _invalidJson}} -> {:error, "Internal Server Error"}
          {:error, reason} -> error
          error -> {:error, "Internal Server Error"}
        end
    end
  end

  def get_user_info(token) do
    case HTTPoison.get(user_info_endpoint(), [{"Authorization", "Bearer #{token}"}]) do
      {:ok, %{body: body, status_code: status_code}} when status_code in 200..399 -> Jason.decode(body)
      error -> {:error, "Unauthorized"}
    end
  end

  defp user_info_endpoint() do
    issuer =
      Application.get_env(:discovery_api, DiscoveryApiWeb.Auth.TokenHandler)
      |> Keyword.fetch!(:issuer)

    issuer <> "userinfo"
  end
end
