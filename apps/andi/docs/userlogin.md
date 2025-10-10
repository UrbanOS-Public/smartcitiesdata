# Andi User Login Process

## Overview

The Andi web application implements OAuth 2.0 authentication using Auth0 as the identity provider with role-based access control. The authentication system uses the Guardian library for JWT token management and Ueberauth for OAuth integration.

## Authentication Flow

### 1. Initial Request
When a user tries to access a protected route without being authenticated:
- The request passes through the `:auth` pipeline (`AndiWeb.Auth.Pipeline`)
- `Guardian.Plug.VerifySession` checks for a valid session token
- `Guardian.Plug.VerifyHeader` checks for tokens in the Authorization header
- `Guardian.Plug.LoadResource` attempts to load the user resource
- If authentication fails, `AndiWeb.Auth.ErrorHandler` redirects to `/auth/auth0?prompt=login`

### 2. OAuth Initiation
The authentication process begins when users are redirected to:
```
GET /auth/auth0
```
This triggers the Ueberauth Auth0 strategy with the following configuration:
- **Provider**: Auth0
- **Default Audience**: "andi"
- **Allowed Parameters**: scope, state, audience, connection, prompt, screen_hint, login_hint, error_message

### 4. Auth0 MDOT Flow
- Auth0 is configured to use a Authentication/Social connection to authorize users from MIWorker
- If MIWorker authenticates the user, auth0 succesfully creates tokens for the user and the rest of the flow is continued.

### 5. Auth0 Callback
After successful authentication with Auth0, the user is redirected to:
```
GET /auth/auth0/callback
```

The `AndiWeb.AuthController.callback/2` function handles this with two scenarios:

#### Success Flow (`AndiWeb.AuthController:27-38`)
1. **User Creation/Update**: Creates or updates user record in local database using `Andi.Schemas.User.create_or_update/2`
2. **SmartCity User Creation**: Creates a SmartCity.User struct for event processing
3. **Event Broadcasting**: If private access is enabled, sends a user_login event via Brook
4. **Session Management**: Stores JWT token in session via `TokenHandler.put_session_token/2`
5. **Redirect**: Redirects user to home page (`/`)

#### Failure Flow (`AndiWeb.AuthController:20-25`)
1. **Error Logging**: Logs authentication failure details
2. **Redirect**: Redirects to `/autherror` page

### 6. Token Management

#### JWT Token Handling (`AndiWeb.Auth.TokenHandler`)
- **Storage**: JWT tokens are stored in Plug.Session cookies
- **Resource Loading**: `resource_from_claims/1` extracts user information from JWT claims:
  - User ID from local database lookup by `subject_id`
  - Roles from `https://andi.smartcolumbusos.com/roles` claim
  - Curator status based on "Curator" role membership

#### Token Structure
```elixir
%{
  "user_id" => user_id,           # Local database user ID
  "roles" => roles,               # Array of role strings
  "is_curator" => is_curator      # Boolean for curator access
}
```

### 7. Role-Based Access Control

The application implements a two-tier access system:

#### Basic Authentication (`:auth` pipeline)
- Required for all protected routes
- Verifies valid JWT token
- Loads user resource

#### Curator Access (`:curator` pipeline)
- Required for administrative functions
- Enforces "Curator" role requirement via Guardian claims
- Applied to routes: `/organizations`, `/users`, `/access-groups`, `/ingestions`, `/reports`

### 8. Logout Process

#### User-Initiated Logout (`AndiWeb.AuthController.logout/2`)
1. **Token Revocation**: Calls `TokenHandler.log_out/1` which:
   - Signs out user via `AndiWeb.Auth.TokenHandler.Plug.sign_out/1`
   - Constructs Auth0 logout URL with return URL
   - Redirects to Auth0 logout endpoint
2. **Auth0 Logout**: User is logged out of Auth0 session
3. **Return**: Auth0 redirects back to Andi login page

#### Logout URL Structure
```
{auth0_domain}/v2/logout?returnTo={andi_login_url}&client_id={client_id}
```

### 9. Error Handling

#### Authentication Errors (`AndiWeb.Auth.ErrorHandler`)
- **Unauthorized Role**: Redirects to login with "Unauthorized" error message
- **General Auth Errors**: Redirects to login page with prompt
- **Telemetry**: Records login failure metrics

#### Error Scenarios
1. **No Authentication**: Redirect to `/auth/auth0?prompt=login`
2. **Insufficient Roles**: Redirect to `/auth/auth0?prompt=login&error_message=Unauthorized`
3. **Auth0 Callback Failure**: Redirect to `/autherror`

## Configuration

### Ueberauth Configuration (`config/config.exs:41-58`)
```elixir
config :ueberauth, Ueberauth,
  providers: [
    auth0: {Ueberauth.Strategy.Auth0, [
      default_audience: "andi",
      allowed_request_params: [
        :scope, :state, :audience, :connection, :prompt,
        :screen_hint, :login_hint, :error_message
      ]
    ]}
  ]
```

### Guardian Configuration
- **OTP App**: `:andi`
- **Token Handler**: `AndiWeb.Auth.TokenHandler`
- **Error Handler**: `AndiWeb.Auth.ErrorHandler`

## Database Schema

### Users Table (`Andi.Schemas.User`)
- **id**: UUID primary key
- **subject_id**: Auth0 user identifier (unique)
- **name**: User display name
- **email**: User email address
- **Relationships**:
  - `has_many :datasets` (owned datasets)
  - `many_to_many :organizations` (organization memberships)
  - `many_to_many :access_groups` (access group memberships)

## Security Features

1. **CSRF Protection**: Enabled via `:protect_from_forgery` plug
2. **Secure Headers**: Content Security Policy and HSTS support
3. **Session Security**: JWT tokens stored in secure session cookies
4. **Role Validation**: Server-side role verification from JWT claims
5. **Token Revocation**: Logout invalidates session tokens

## Telemetry Events

The authentication system generates telemetry events for monitoring:
- `[:andi_login_success]`: Successful authentication
- `[:andi_login_failure]`: Authentication failures
- `[:andi_logout_success]`: Successful logout

## API Authentication

For API endpoints under `/api`, the application uses the `:api_curator` pipeline which enforces curator-level access via `AndiWeb.Plugs.APIRequireCurator`.

## Testing

The authentication system includes comprehensive test coverage:
- **Integration Tests**: Full OAuth flow simulation (`auth_test.exs`)
- **Unit Tests**: Controller and helper function testing
- **Mock Support**: Auth connection cases for different user roles

