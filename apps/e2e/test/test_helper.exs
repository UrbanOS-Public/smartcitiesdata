ExUnit.start(exclude: [:e2e, :skip], seed: 0, timeout: 300_000)

# Define behaviours for mocking
defmodule BrookMock do
  @callback get(atom(), atom(), any()) :: {:ok, term()} | {:error, String.t()}
  @callback get!(atom(), atom(), any()) :: any() | nil
  @callback get_all(atom(), atom()) :: {:ok, map()} | {:error, String.t()}
  @callback create(atom(), atom(), any(), any()) :: :ok | {:error, any()}
  @callback delete(atom(), atom(), any()) :: :ok | {:error, any()}
end

defmodule RaptorServiceBehaviour do
  @callback is_authorized(String.t(), String.t(), String.t()) :: boolean()
  @callback get_user_id_from_api_key(String.t(), String.t()) :: {:ok, String.t()} | {:error, String.t(), String.t()}
end

# Define mocks needed for discovery_streams integration
Mox.defmock(BrookViewStateMock, for: BrookMock)
Mox.defmock(RaptorServiceMock, for: RaptorServiceBehaviour)
