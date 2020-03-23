use Mix.Config

config :discovery_api,
  jwks_endpoint: "https://smartcolumbusos-demo.auth0.com/.well-known/jwks.json",
  user_info_endpoint: "https://smartcolumbusos-demo.auth0.com/userinfo"

config :discovery_api, DiscoveryApi.Auth.Guardian, issuer: "https://smartcolumbusos-demo.auth0.com/"
