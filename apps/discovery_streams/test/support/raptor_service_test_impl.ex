defmodule RaptorServiceTestImpl do
  @moduledoc """
  Simple test implementation of RaptorService for integration tests.
  This replaces Mox mocks which should not be used in integration tests.
  """

  @behaviour RaptorServiceBehaviour

  @impl RaptorServiceBehaviour
  def is_authorized(_raptor_url, _api_key, _system_name) do
    # Default behavior: allow all access in integration tests
    # Tests can override this by setting application environment
    case Application.get_env(:discovery_streams, :raptor_test_is_authorized) do
      nil -> true
      value -> value
    end
  end

  @impl RaptorServiceBehaviour
  def get_user_id_from_api_key(_raptor_url, _api_key) do
    {:ok, "test-user-id"}
  end
end
