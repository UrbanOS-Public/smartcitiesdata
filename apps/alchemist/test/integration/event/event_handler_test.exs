defmodule Alchemist.Event.EventHandlerTest do
  use ExUnit.Case
  use Divo
  use Properties, otp_app: :alchemist

  import SmartCity.TestHelper
  import SmartCity.Event
  import Mock

  alias SmartCity.TestDataGenerator, as: TDG
  alias DeadLetter

  @instance_name Alchemist.instance_name()
  getter(:elsa_brokers, generic: true)
  getter(:input_topic_prefix, generic: true)

  describe "Ingestion Update" do
    test "A failing message gets placed on dead letter queue and discarded" do
      id_for_invalid_ingestion = UUID.uuid4()
      invalid_ingestion = TDG.create_ingestion(%{id: id_for_invalid_ingestion})

      id_for_valid_ingestion = UUID.uuid4()
      valid_ingestion = TDG.create_ingestion(%{id: id_for_valid_ingestion})
      Brook.Event.send(@instance_name, ingestion_update(), __MODULE__, invalid_ingestion)
      Brook.Event.send(@instance_name, ingestion_update(), __MODULE__, valid_ingestion)

      with_mock(Alchemist.IngestionProcessor, [start: fn(invalid_ingestion) -> raise "nope" end]) do
        eventually(fn ->
          failed_messages =
            Elsa.Fetch.fetch(elsa_brokers(), "dead-letters")
            |> elem(2)
            |> Enum.filter(fn message ->
              actual = Jason.decode!(message.value)

              case actual["original_message"] do
                %{"id" => message_ingestion_id} ->
                  message_ingestion_id == id_for_invalid_ingestion

                _ ->
                  false
              end
            end)

          assert 1 == length(failed_messages)
        end)
      end
    end
  end

  describe "Ingestion Delete" do
    test "A failing message gets placed on dead letter queue and discarded" do
      id_for_invalid_ingestion = UUID.uuid4()
      invalid_ingestion = TDG.create_ingestion(%{id: id_for_invalid_ingestion})

      id_for_valid_ingestion = UUID.uuid4()
      valid_ingestion = TDG.create_ingestion(%{id: id_for_valid_ingestion})

      Brook.Event.send(@instance_name, ingestion_delete(), __MODULE__, invalid_ingestion)
      Brook.Event.send(@instance_name, ingestion_update(), __MODULE__, valid_ingestion)

      with_mock(Alchemist.IngestionProcessor, [delete: fn(invalid_ingestion) -> raise "nope" end]) do
        eventually(fn ->
          failed_messages =
            Elsa.Fetch.fetch(elsa_brokers(), "dead-letters")
            |> elem(2)
            |> Enum.filter(fn message ->
              actual = Jason.decode!(message.value)

              case actual["original_message"] do
                %{"id" => message_ingestion_id} ->
                  message_ingestion_id == id_for_invalid_ingestion

                _ ->
                  false
              end
            end)

          assert 1 == length(failed_messages)
        end)
      end
    end
  end
end
