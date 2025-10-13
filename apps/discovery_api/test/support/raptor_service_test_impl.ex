defmodule RaptorServiceTestImpl do
  @moduledoc """
  Simple test implementation of RaptorService that doesn't use Mox
  """

  @behaviour RaptorServiceBehaviour

  @impl RaptorServiceBehaviour
  def list_access_groups_by_dataset(_raptor_url, _dataset_id) do
    # Return an empty list of access groups for tests
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
  def is_authorized_by_user_id(_raptor_url, user_id, system_name) do
    # Check if test has configured specific authorization behavior
    case Process.get(:raptor_auth_rules) do
      nil ->
        # Default: allow all access
        true

      rules when is_list(rules) ->
        # Check if any rule matches and denies access
        case Enum.find(rules, fn rule -> matches_rule?(rule, user_id, system_name) end) do
          {:deny, _user, _dataset} -> false
          {:allow, _user, _dataset} -> true
          # No matching rule, default to allow
          nil -> true
        end
    end
  end

  defp matches_rule?({_action, :any, dataset}, _user_id, system_name), do: dataset == system_name
  defp matches_rule?({_action, user, :any}, user_id, _system_name), do: user == user_id
  defp matches_rule?({_action, user, dataset}, user_id, system_name), do: user == user_id && dataset == system_name

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
