defmodule AndiWeb.Auth.TokenHandler do
  @moduledoc false
  use Guardian,
    otp_app: :andi,
    allowed_algos: ["RS256"],
    issuer: "https://smartcolumbusos-demo.auth0.com/",
    secret_fetcher: Andi.Auth.Auth0.SecretFetcher,
    verify_issuer: true

  def subject_for_token(resource, _claims) do
    IO.inspect(resource, label: "subject_for_token")
    {:ok, resource}
  end

  def resource_from_claims(claims) do
    IO.inspect(claims, label: "resource_From_claims")
    %{"dog" => "cat"}
  end

  def on_verify(claims, _token, _options) do
    IO.inspect(claims, label: "on_verify")
    {:ok, Map.put(claims, "typ", "JWT")}
  end
end
