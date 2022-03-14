defmodule Auth.Guardian.TokenHandler do
  @moduledoc """
  A module that hooks into Guardian's token lifecycle in order to provide extra verifications.
  Primarily, this module introduces Guardian.DB for token revocation purposes.

  Major differences with usual Guardian.DB implementation:
  - we don't generate the token in the API
  - we only track revoked tokes, not ALL tokens
  - verification in this case checks if the token has been revoked, not that it exists in the DB
  """

  defmacro __using__(opts) do
    options =
      Keyword.merge(
        [secret_fetcher: Auth.Auth0.SecretFetcher],
        opts
      )

    quote do
      @token_type "JWT"
      use Guardian, unquote(options)

      @doc """
      Overridable implementation for determining a resource's subject
      """
      def subject_for_token(resource, _claims) do
        {:ok, resource}
      end

      @doc """
      Overridable implementation for filling out the details of a resource
      """
      def resource_from_claims(claims) do
        {:ok, claims["sub"]}
      end

      defoverridable subject_for_token: 2, resource_from_claims: 1

      @doc """
      Called after a token has been created by guardian

      Not applicable for the UrbanOS use case, but required by Guardian
      """
      def after_encode_and_sign(_resource, _claims, token, _options) do
        {:ok, token}
      end

      @doc """
      Called after a token has been verified (signature, expiry, etc.)

      This makes an additional check to make sure it isn't explicitly revoked
      """
      def on_verify(claims, _token, _options) do
        case claims_revoked?(claims) do
          false -> {:ok, claims}
          true -> {:error, :invalid_token}
        end
      rescue
        e -> {:error, e}
      end

      @doc """
      Called after a token has been revoked

      Adds the token, identified by a hash of its claims to a revocation list.
      It will expire out of the list once it's exp time has been hit
      """
      def on_revoke(claims, token, _options) do
        revoke_claims(claims, token)
      rescue
        e -> {:error, e}
      end

      @doc """
      Called after a token has been refreshed

      Does a fairly boilerplate swap of the token and claims
      """
      def on_refresh({old_token, old_claims}, {new_token, new_claims}, _options) do
        {:ok, {old_token, old_claims}, {new_token, new_claims}}
      end

      defp claims_revoked?(claims) do
        revoked_claims = to_revoked_claims(claims)

        case Guardian.DB.Token.find_by_claims(revoked_claims) do
          nil -> false
          _ -> true
        end
      end

      defp revoke_claims(claims, token) do
        revoked_claims = to_revoked_claims(claims)

        case Guardian.DB.Token.create(revoked_claims, token) do
          {:ok, _} -> {:ok, claims}
          _ -> {:error, :failed_to_revoke_claims}
        end
      end

      def claims_to_jwtid(claims) do
        claims
        |> to_sorted_list()
        |> stringify()
        |> hash()
      end

      def to_revoked_claims(claims) do
        jwtid = claims_to_jwtid(claims)

        claims
        |> Map.put("typ", @token_type)
        |> Map.put("jti", jwtid)
        |> Map.update("aud", "", &Enum.join(&1, " "))
      end

      defp to_sorted_list(claims) do
        claims
        |> Map.to_list()
        |> Enum.sort_by(&elem(&1, 0))
      end

      defp stringify(claims) do
        :erlang.term_to_binary(claims)
      end

      defp hash(hashable) do
        :crypto.hash(:sha256, hashable)
        |> Base.encode16()
      end
    end
  end
end
