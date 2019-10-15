defmodule Andi.Services.OrganizationReposter do
  @moduledoc """
  This module can be used to repost all organizations in andi's Brook store to
    the brook event stream as organization_update events.
  This can be used when another app needs to re-read all organizations as update events.
  """
  require Logger
  import Andi
  import SmartCity.Event, only: [organization_update: 0]

  def repost_all_orgs() do
    with {:ok, orgs} <- Brook.get_all_values(instance_name(), :org),
         :ok <- send_all(orgs) do
      :ok
    else
      {_, error} ->
        Logger.error("Failed to repost organizations: #{inspect(error)}")
        {:error, error}
    end
  end

  defp send_all(organizations) do
    case send_all_collecting_errors(organizations) do
      [] -> :ok
      _ -> {:error, "Failed to repost all organizations"}
    end
  end

  defp send_all_collecting_errors(organizations) do
    organizations
    |> Enum.map(&Brook.Event.send(instance_name(), organization_update(), :andi, &1))
    |> Enum.filter(fn result -> {:error, _} = result end)
  end
end
