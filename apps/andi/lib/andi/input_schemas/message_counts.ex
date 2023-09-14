defmodule Andi.InputSchemas.MessageCounts do
  @moduledoc false
  alias Andi.Repo
  alias Ecto.Changeset
  alias Andi.InputSchemas.MessageCount

  use Properties, otp_app: :andi

  import Ecto.Query

  require Logger

  def get(nil), do: nil

  def get_by(extraction_start_time, ingestion_id) do
    Repo.get_by(MessageCount, %{ingestion_id: ingestion_id, extraction_start_time: extraction_start_time})
  end

  def get_all() do
    query = from(messageCount in MessageCount)

    Repo.all(query)
  end

  def get_errors_in_last_seven_days(dataset_id) do
    query = from(
      messageCount in MessageCount,
      where: messageCount.dataset_id == ^dataset_id,
      where: messageCount.actual_message_count != messageCount.expected_message_count,
      where: messageCount.extraction_start_time > ago(2, "minute")
    )

    Repo.all(query)
  end

  def update(%{} = message_count) do
    MessageCount.changeset(message_count) |> IO.inspect(label: "changeset")
    |> Repo.insert_or_update()
  end

  def update(%{} = message_count, changes) do
    MessageCount.changeset(message_count, changes) |> IO.inspect(label: "changeset")
    |> Repo.insert_or_update()
  end

  def delete(%MessageCount{} = message_count) do
    Repo.delete(message_count)
  rescue
    _e in Ecto.StaleEntryError ->
      {:error, "attempted to remove a message_count: #{inspect(message_count)} that does not exist."}
  end

  def delete_all_before_date(value, unit) do
    query =
      from(
        messageCount in MessageCount,
        where: messageCount.extraction_start_time < ago(^value, ^unit)
      )

    Repo.delete_all(query)
  end
end
