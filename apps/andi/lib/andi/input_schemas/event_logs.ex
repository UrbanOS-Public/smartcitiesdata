defmodule Andi.InputSchemas.EventLogs do
  @moduledoc false
  alias Andi.Repo
  alias Ecto.Changeset
  alias Andi.InputSchemas.EventLog

  use Properties, otp_app: :andi

  import Ecto.Query

  require Logger

  def get(nil), do: nil

  def get(id) do
    Repo.get(EventLog, id)
  end

  def get_all() do
    query = from(eventlog in EventLog)

    Repo.all(query)
  end

  def get_all_for_dataset_id(dataset_id) do
    query = from(eventlog in EventLog, where: eventlog.dataset_id == ^dataset_id)

    Repo.all(query)
  end

  def update(%SmartCity.EventLog{} = event_log) do
    EventLog.changeset(event_log)
    |> Repo.insert_or_update()
  end

  def delete(%EventLog{} = event_log) do
    Repo.delete(event_log)
  rescue
    _e in Ecto.StaleEntryError ->
      {:error, "attempted to remove an eventlog: #{inspect(event_log)} that does not exist."}
  end
end
