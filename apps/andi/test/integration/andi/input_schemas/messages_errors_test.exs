defmodule Andi.InputSchemas.MessageErrorsTest do
  use ExUnit.Case
  use Andi.DataCase

  alias Andi.InputSchemas.MessageError
  alias Andi.InputSchemas.MessageErrors

  alias Andi.Repo

  describe "get_all/0" do
    test "returns all results from andi repo" do
      message_error_1 = %{
        ingestion_id: UUID.uuid4(),
        dataset_id: UUID.uuid4(),
        has_current_error: false,
        last_error_time: DateTime.from_unix!(0)
      }

      message_error_2 = %{
        ingestion_id: UUID.uuid4(),
        dataset_id: UUID.uuid4(),
        has_current_error: true,
        last_error_time: DateTime.from_unix!(1)
      }

      expected = [message_error_1, message_error_2]

      MessageErrors.update(message_error_1)
      MessageErrors.update(message_error_2)

      actual =
        MessageErrors.get_all()
        |> Enum.sort(fn error1, error2 -> DateTime.to_unix(error1.last_error_time) < DateTime.to_unix(error2.last_error_time) end)
        |> Enum.map(fn messageError ->
          %{
            ingestion_id: messageError.ingestion_id,
            dataset_id: messageError.dataset_id,
            has_current_error: messageError.has_current_error,
            last_error_time: messageError.last_error_time
          }
        end)

      assert actual == expected
    end
  end

  describe "get_latest_error/1" do
    test "returns default error object when not found" do
      dataset_id = "missingDatasetId"

      expected = %MessageError{
        dataset_id: dataset_id,
        last_error_time: DateTime.from_unix!(0),
        has_current_error: false
      }

      actual = MessageErrors.get_latest_error(dataset_id)

      assert actual == expected
    end

    test "returns message error object for a datasetId" do
      dataset_id_1 = UUID.uuid4()

      message_error_1 = %{
        ingestion_id: UUID.uuid4(),
        dataset_id: dataset_id_1,
        has_current_error: false,
        last_error_time: DateTime.from_unix!(0)
      }

      message_error_2 = %{
        ingestion_id: UUID.uuid4(),
        dataset_id: UUID.uuid4(),
        has_current_error: true,
        last_error_time: DateTime.from_unix!(1)
      }

      MessageErrors.update(message_error_1)
      MessageErrors.update(message_error_2)

      actual = MessageErrors.get_latest_error(dataset_id_1)

      assert actual.ingestion_id == message_error_1.ingestion_id
      assert actual.dataset_id == message_error_1.dataset_id
      assert actual.has_current_error == message_error_1.has_current_error
      assert actual.last_error_time == message_error_1.last_error_time
    end
  end

  describe "update/1" do
    test "adds error message" do
      dataset_id = UUID.uuid4()

      message_error = %{
        ingestion_id: UUID.uuid4(),
        dataset_id: dataset_id,
        has_current_error: false,
        last_error_time: DateTime.from_unix!(0)
      }

      MessageErrors.update(message_error)

      actual = MessageErrors.get_latest_error(dataset_id)

      assert actual.ingestion_id == message_error.ingestion_id
      assert actual.dataset_id == message_error.dataset_id
      assert actual.has_current_error == message_error.has_current_error
      assert actual.last_error_time == message_error.last_error_time
    end

    test "updates error message with given changes" do
      dataset_id = UUID.uuid4()

      existing_message_error = %{
        ingestion_id: UUID.uuid4(),
        dataset_id: dataset_id,
        has_current_error: false,
        last_error_time: DateTime.from_unix!(0)
      }

      MessageErrors.update(existing_message_error)

      changes = %{
        ingestion_id: UUID.uuid4(),
        dataset_id: dataset_id,
        has_current_error: true,
        last_error_time: DateTime.from_unix!(1)
      }

      MessageErrors.update(changes)

      actual = MessageErrors.get_latest_error(dataset_id)

      assert actual.ingestion_id == changes.ingestion_id
      assert actual.dataset_id == changes.dataset_id
      assert actual.has_current_error == changes.has_current_error
      assert actual.last_error_time == changes.last_error_time
    end
  end

  describe "update/2" do
    test "adds error message" do
      dataset_id = UUID.uuid4()

      message_error = %{
        ingestion_id: UUID.uuid4(),
        dataset_id: dataset_id,
        has_current_error: false,
        last_error_time: DateTime.from_unix!(0)
      }

      MessageErrors.update(%MessageError{}, message_error)

      actual = MessageErrors.get_latest_error(dataset_id)

      assert actual.ingestion_id == message_error.ingestion_id
      assert actual.dataset_id == message_error.dataset_id
      assert actual.has_current_error == message_error.has_current_error
      assert actual.last_error_time == message_error.last_error_time
    end

    test "adds error message when given message error is nil" do
      dataset_id = UUID.uuid4()

      message_error = %{
        ingestion_id: UUID.uuid4(),
        dataset_id: dataset_id,
        has_current_error: false,
        last_error_time: DateTime.from_unix!(0)
      }

      MessageErrors.update(nil, message_error)

      actual = MessageErrors.get_latest_error(dataset_id)

      assert actual.ingestion_id == message_error.ingestion_id
      assert actual.dataset_id == message_error.dataset_id
      assert actual.has_current_error == message_error.has_current_error
      assert actual.last_error_time == message_error.last_error_time
    end

    test "updates error message with given changes" do
      dataset_id = UUID.uuid4()

      existing_message_error = %{
        ingestion_id: UUID.uuid4(),
        dataset_id: dataset_id,
        has_current_error: false,
        last_error_time: DateTime.from_unix!(0)
      }

      MessageErrors.update(existing_message_error)

      actual_existing = MessageErrors.get_latest_error(dataset_id)

      changes = %{
        ingestion_id: UUID.uuid4(),
        dataset_id: dataset_id,
        has_current_error: true,
        last_error_time: DateTime.from_unix!(1)
      }

      MessageErrors.update(actual_existing, changes)

      actual_new = MessageErrors.get_latest_error(dataset_id)

      assert actual_new.ingestion_id == changes.ingestion_id
      assert actual_new.dataset_id == changes.dataset_id
      assert actual_new.has_current_error == changes.has_current_error
      assert actual_new.last_error_time == changes.last_error_time
    end
  end

  describe "delete/1" do
    test "deletes existing error message" do
      dataset_id = UUID.uuid4()

      message_error = %{
        ingestion_id: UUID.uuid4(),
        dataset_id: dataset_id,
        has_current_error: true,
        last_error_time: DateTime.from_unix!(1)
      }

      default_response = %{
        dataset_id: dataset_id,
        has_current_error: false,
        last_error_time: DateTime.from_unix!(0)
      }

      {:ok, saved_error} = MessageErrors.update(message_error)

      MessageErrors.delete(saved_error)

      actual = MessageErrors.get_latest_error(dataset_id)

      assert actual.ingestion_id == nil
      assert actual.dataset_id == default_response.dataset_id
      assert actual.has_current_error == default_response.has_current_error
      assert actual.last_error_time == default_response.last_error_time
    end

    test "throws error when attempting to delete non existing message error" do
      dataset_id = UUID.uuid4()
      ingestion_id = UUID.uuid4()

      not_existing_message_error = %MessageError{
        ingestion_id: ingestion_id,
        dataset_id: dataset_id,
        has_current_error: false,
        last_error_time: DateTime.from_unix!(0)
      }

      result = MessageErrors.delete(not_existing_message_error)

      assert result ==
               {:error,
                "attempted to remove a message_count: %Andi.InputSchemas.MessageError{__meta__: #Ecto.Schema.Metadata<:built, \"message_error\">, dataset_id: \"#{
                  dataset_id
                }\", has_current_error: false, ingestion_id: \"#{ingestion_id}\", last_error_time: ~U[1970-01-01 00:00:00Z]} that does not exist."}
    end
  end

  describe "delete_all_before_date/2" do
    test "deletes all message errors before given date" do
      dataset_id_1 = UUID.uuid4()
      dataset_id_2 = UUID.uuid4()
      dataset_id_3 = UUID.uuid4()

      ingestion_id_1 = UUID.uuid4()

      last_error_time_1 = DateTime.utc_now()

      message_error_1 = %{
        ingestion_id: ingestion_id_1,
        dataset_id: dataset_id_1,
        has_current_error: true,
        last_error_time: last_error_time_1
      }

      message_error_2 = %{
        ingestion_id: UUID.uuid4(),
        dataset_id: dataset_id_2,
        has_current_error: false,
        last_error_time: DateTime.add(DateTime.utc_now(), 1 * 24 * -3600)
      }

      message_error_3 = %{
        ingestion_id: UUID.uuid4(),
        dataset_id: dataset_id_3,
        has_current_error: true,
        last_error_time: DateTime.add(DateTime.utc_now(), 2 * 24 * -3600)
      }

      MessageErrors.update(message_error_1)
      MessageErrors.update(message_error_2)
      MessageErrors.update(message_error_3)

      MessageErrors.delete_all_before_date(1, "day")

      actual = MessageErrors.get_all()
      remaining_message = List.last(actual)

      assert length(actual) == 1
      assert remaining_message.ingestion_id == ingestion_id_1
      assert remaining_message.dataset_id == dataset_id_1
      assert remaining_message.has_current_error == true
      assert remaining_message.last_error_time == DateTime.truncate(last_error_time_1, :second)
    end
  end
end
