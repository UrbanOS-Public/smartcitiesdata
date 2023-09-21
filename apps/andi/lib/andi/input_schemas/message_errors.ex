defmodule Andi.InputSchemas.MessageErrors do
  @moduledoc false
  alias Andi.Repo
  alias Ecto.Changeset
  alias Andi.InputSchemas.MessageError

  use Properties, otp_app: :andi

  import Ecto.Query, only: [from: 1, from: 2]

  require Logger

  def get_all() do
    query = from(messageError in MessageError)

    Repo.all(query)
  end

  def get_latest_error(dataset_id) do
    case Repo.get_by(MessageError, %{dataset_id: dataset_id}) do
      nil -> get_default(dataset_id)
      message_error -> message_error
    end
  end

  def update(%{} = changes) do
    original_message_error = get_latest_error(changes.dataset_id)

    update(original_message_error, changes)
  end

  def update(%MessageError{} = existing_message_error, %{} = changes) do
    MessageError.changeset(existing_message_error, changes)
    |> Repo.insert_or_update()
  end

  def update(nil, %{} = changes) do
    update(changes)
  end

  def delete(%MessageError{} = message_error) do
    Repo.delete(message_error)
  rescue
    _e in Ecto.StaleEntryError ->
      {:error, "attempted to remove a message_count: #{inspect(message_error)} that does not exist."}
  end

  def delete_all_before_date(value, unit) do
    query =
      from(
        messageError in MessageError,
        where: messageError.last_error_time < ago(^value, ^unit)
      )

    Repo.delete_all(query)
  end

  defp get_default(dataset_id) do
    %MessageError{
      dataset_id: dataset_id,
      last_error_time: DateTime.from_unix!(0),
      has_current_error: false
    }
  end
end
