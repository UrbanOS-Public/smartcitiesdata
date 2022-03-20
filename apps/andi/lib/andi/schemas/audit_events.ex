defmodule Andi.Schemas.AuditEvents do
  @moduledoc false
  alias Andi.Schemas.AuditEvent
  alias Andi.Repo
  alias Andi.InputSchemas.StructTools

  import Ecto.Query, only: [from: 2]

  require Logger

  def create(new_audit_event_changes) do
    {:ok, new_changeset} =
      new_audit_event_changes
      |> AuditEvent.changeset()
      |> Repo.insert_or_update()

    new_changeset
  end

  def get(id), do: Repo.get(AuditEvent, id)

  def get_all(), do: Repo.all(AuditEvent)

  def get_all_for_user(user_id) do
    query =
      from(event in AuditEvent,
        where: event.user_id == ^user_id
      )

    Repo.all(query)
  end

  def get_all_of_type(event_type) do
    query =
      from(event in AuditEvent,
        where: event.event_type == ^event_type
      )

    Repo.all(query)
  end

  def get_all_in_range(start_date, end_date) do
    {:ok, start_datetime} = NaiveDateTime.new(start_date, ~T[00:00:00])
    {:ok, end_datetime} = NaiveDateTime.new(end_date, ~T[00:00:00])

    query =
      from(event in AuditEvent,
        where:
          event.inserted_at >= ^start_datetime and
            event.inserted_at <= ^end_datetime
      )

    Repo.all(query)
  end
end
