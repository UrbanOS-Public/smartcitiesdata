# HashiCorp Vault Integration Analysis - SmartCitiesData Project

## Overview

  The SmartCitiesData project uses HashiCorp Vault to securely store and retrieve application secrets across multiple services (Reaper, Forklift, and Andi). The integration uses Kubernetes authentication with service account tokens.

###  Vault URL Construction Parameters

####  Base Configuration

  Environment Variable: SECRETS_ENDPOINT
  - Test Environment: "http://vault:8200" (apps/reaper/config/test.exs:15)
  - Runtime Environment: System.get_env("SECRETS_ENDPOINT") (apps/reaper/runtime.exs:56)

####  URL Structure Components

  1. Host Configuration

  host: secrets_endpoint()
  - Source: @secrets_endpoint property from application config
  - Format: Complete URL including protocol and port (e.g., http://vault:8200)

  2. Vault Path Construction

  Root Path: "secrets/smart_city/"

  Service-Specific Paths:
  - Reaper: "secrets/smart_city/ingestion/{ingestion_id}"
  - Forklift: "secrets/smart_city/aws_keys/forklift"
  - Andi: "secrets/smart_city/ingestion/{ingestion_id}" (read/write)

  3. Complete URL Pattern

  {SECRETS_ENDPOINT}/v1/{engine_mount}/secrets/smart_city/{service_path}

  Where:
  - {SECRETS_ENDPOINT}: Base Vault server URL
  - {engine_mount}: KV Version 1 engine mount path
  - {service_path}: Service-specific secret path

###  Authentication Parameters

####  Kubernetes Authentication

#####  Authentication Method: Vault.Auth.Kubernetes

  Token Source: /var/run/secrets/kubernetes.io/serviceaccount/token
  - Standard Kubernetes service account token location
  - Automatically mounted in pods by Kubernetes

  Role-Based Access:
  - Reaper: "reaper-role"
  - Forklift: "forklift-role"
  - Andi: Configurable via vault_role() property

#####  Connection Parameters

  Vault.new(
    engine: Vault.Engine.KVV1,
    auth: Vault.Auth.Kubernetes,
    host: secrets_endpoint(),
    token_expires_at: set_login_ttl(20, :second)
  )
  |> Vault.auth(%{role: "{service}-role", jwt: token})

#####  Key Parameters:

  - Engine: Vault.Engine.KVV1 (Key-Value Version 1)
  - TTL: 20 seconds token expiration
  - Role: Service-specific Kubernetes role
  - JWT: Kubernetes service account token

####  Secret Retrieval Patterns

  Service-Specific Usage

#####  Reaper Service

  File: apps/reaper/lib/reaper/secret_retriever.ex
  - Purpose: Retrieve ingestion credentials
  - Path: "secrets/smart_city/ingestion/{ingestion_id}"
  - Function: retrieve_ingestion_credentials(ingestion_id)

#####  Forklift Service

  File: apps/forklift/lib/forklift/secret_retriever.ex
  - Purpose: Retrieve AWS object store keys
  - Path: "secrets/smart_city/aws_keys/forklift"
  - Function: retrieve_objectstore_keys()

#####  Andi Service

  File: apps/andi/lib/andi/secret_service.ex
  - Purpose: Retrieve/write ingestion credentials and auth0 config
  - Read Path: "secrets/smart_city/ingestion/{ingestion_id}"
  - Write Path: "secrets/smart_city/ingestion/{path}"
  - Functions: retrieve_ingestion_credentials(id), write(path, secret)

#####  Error Handling

  All services implement consistent error patterns:
  1. Token File Missing: {:error, "Secret token file not found"}
  2. Vault Connection Failure: {:error, reason} from Vault.auth
  3. Secret Read/Write Failure: {:error, reason} from Vault operations
  4. Final Error: {:error, :retrieve_credential_failed} or {:error, :write_credential_failed}

#####  Security Features

  - Service Account Isolation: Each service uses dedicated Kubernetes roles
  - Token Rotation: 20-second TTL forces frequent re-authentication
  - Path Isolation: Service-specific secret paths prevent cross-service access
  - Secure Token Storage: Uses Kubernetes-mounted service account tokens

  This architecture provides secure, role-based secret management with automatic token rotation and service isolation for the SmartCitiesData platform's data ingestion pipeline.

## Overview of the steps to look up the Vault.Auth.Kubernetes token

  The urbanos components use the libvault Elixir library to perform HashiCorp Vault authentication via Kubernetes service accounts. Here's exactly how Vault.Auth.Kubernetes constructs and executes web service requests:

###  Authentication Request Lifecycle

####  1. Initial Setup and Configuration

  File: apps/reaper/lib/reaper/secret_retriever.ex:38-46
```elixir
  Vault.new(
    engine: Vault.Engine.KVV1,
    auth: Vault.Auth.Kubernetes,
    host: secrets_endpoint(),      # e.g., "http://vault:8200"
    token_expires_at: set_login_ttl(20, :second)
  )
  |> Vault.auth(%{role: "reaper-role", jwt: token})
```

###  2. Authentication Flow Execution

####  Step 1: Vault.auth() Orchestration

  File: /deps/libvault/lib/vault.ex:239-242
```elixir
  def auth(%__MODULE__{auth: auth, credentials: creds} = vault, params) do
    new_creds = if is_map(creds), do: Map.merge(creds, params), else: params
    case auth.login(vault, new_creds) do  # Calls Vault.Auth.Kubernetes.login/2
```

####  Step 2: Kubernetes Authentication Logic

  File: /deps/libvault/lib/vault/auth/kubernetes.ex:30-32
```elixir
  def login(%Vault{auth_path: path} = vault, params) do
    with {:ok, params} <- validate_params(params),
         {:ok, body} <- Vault.HTTP.post(vault, url(path), body: params, headers: headers()) do

  URL Construction (kubernetes.ex:66-68):
  defp url(path) do
    "auth/" <> path <> "/login"  # Results in: "auth/kubernetes/login"
  end
```

####  Step 3: HTTP Request Construction

  File: /deps/libvault/lib/vault/http/http.ex:55-67
```elixir
  def request(%Vault{http: http, host: host, json: json, token: token}, method, path, options) do
    body = Keyword.get(options, :body, %{})           # {role: "reaper-role", jwt: "k8s-jwt-token"}
    headers = Keyword.get(options, :headers, [])      # [{"Content-Type", "application/json"}]
    version = Keyword.get(options, :version, "v1")    # Default: "v1"
    path = String.trim_leading(path, "/")             # "auth/kubernetes/login"
    url = "#{host}/#{version}/#{path}" # "http://vault:8200/v1/auth/kubernetes/login"
```

####  Step 4: Tesla HTTP Adapter Execution

  File: /deps/libvault/lib/vault/http/tesla.ex:53-56
```elixir
  def request(method, url, params, headers, http_options) do
    Tesla.request(client(http_options),
      method: :post,                                    # POST request
      url: "http://vault:8200/v1/auth/kubernetes/login", # Full URL
      headers: [{"Content-Type", "application/json"}],   # JSON headers
      body: "{\"role\":\"reaper-role\",\"jwt\":\"k8s-service-account-token\"}"  # JSON body
    )
  end
```

###  Complete Web Service Request Details

  HTTP Request Structure
```
  POST /v1/auth/kubernetes/login HTTP/1.1
  Host: vault:8200
  Content-Type: application/json

  {
    "role": "reaper-role",
    "jwt": "eyJhbGciOiJSUzI1NiIsImtpZCI6Ii..."  // Kubernetes service account JWT
  }
```

####  URL Components Breakdown

  - Base URL: From SECRETS_ENDPOINT environment variable (http://vault:8200)
  - API Version: /v1/ (hardcoded default)
  - Auth Method: /auth/kubernetes/ (set by Vault.Auth.Kubernetes adapter)
  - Action: /login (authentication endpoint)
  - Final URL: http://vault:8200/v1/auth/kubernetes/login

####  Request Parameters

  1. Role: Service-specific Kubernetes role ("reaper-role", "forklift-role")
  2. JWT: Kubernetes service account token read from /var/run/secrets/kubernetes.io/serviceaccount/token

####  Authentication Response Processing

  File: /deps/libvault/lib/vault/auth/kubernetes.ex:33-42

```elixir
  case body do
    %{"errors" => messages} ->
      {:error, messages}
    %{"auth" => %{"client_token" => token, "lease_duration" => ttl}} ->
      {:ok, token, ttl}  # Returns Vault token + expiration time
  end
```

####  Token Storage and Usage

  File: /deps/libvault/lib/vault.ex:242-252

  After successful authentication:
  ```elixir
  {:ok, token, ttl} ->
    expires_at = NaiveDateTime.utc_now() |> NaiveDateTime.add(ttl, :second)
    {:ok, %{vault | token: token, token_expires_at: expires_at}}
```

  The returned Vault token is then used in subsequent API calls via the X-Vault-Token header:
  
  File: /deps/libvault/lib/vault/http/http.ex:64
  
  ```elixir
  headers = if token, do: [{"X-Vault-Token", token} | headers], else: headers
```

###  Key Architecture Points for Vault.Auth.Kubernetes token lookup

  1. HTTP Library: Uses Tesla with configurable adapters (Hackney, IBrowse, etc.)
  2. JSON Encoding: Auto-detects Jason or Poison for request/response serialization
  3. Authentication Path: Defaults to /auth/kubernetes/login for Kubernetes auth
  4. Token Management: Automatically handles token expiration and storage
  5. Error Handling: Structured error responses with Vault API error messages
  6. Middleware: Configurable Tesla middleware for retries, logging, redirects

  This architecture provides a clean abstraction over HashiCorp Vault's REST API while maintaining full control over HTTP client configuration and request lifecycle management.


