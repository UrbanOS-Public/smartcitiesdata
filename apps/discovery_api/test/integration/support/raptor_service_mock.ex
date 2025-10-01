defmodule RaptorServiceMock do
  @moduledoc """
  Mock implementation of RaptorService for integration tests
  """

  @behaviour RaptorServiceBehaviour

  @impl RaptorServiceBehaviour
  def list_access_groups_by_dataset(_raptor_url, _dataset_id) do
    # Return an empty list of access groups for integration tests
    %{access_groups: []}
  end

  @impl RaptorServiceBehaviour
  def list_groups_by_user(_raptor_url, _user_id) do
    %{
      access_groups: [],
      organizations: []
    }
  end

  @impl RaptorServiceBehaviour
  def list_groups_by_api_key(_raptor_url, _api_key) do
    %{
      access_groups: [],
      organizations: []
    }
  end

  @impl RaptorServiceBehaviour
  def is_authorized(_raptor_url, _api_key, _system_name) do
    true
  end

  @impl RaptorServiceBehaviour
  def is_authorized_by_user_id(_raptor_url, _user_id, _system_name) do
    true
  end

  @impl RaptorServiceBehaviour
  def regenerate_api_key_for_user(_raptor_url, _user_id) do
    {:ok, %{"api_key" => "test-api-key"}}
  end

  @impl RaptorServiceBehaviour
  def get_user_id_from_api_key(_raptor_url, _api_key) do
    {:ok, "test-user-id"}
  end

  @impl RaptorServiceBehaviour
  def check_auth0_role(_raptor_url, _user_id, _role) do
    {:ok, true}
  end
end
