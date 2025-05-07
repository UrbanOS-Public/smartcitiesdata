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
  getter(:output_topic_prefix, generic: true)

  describe "Ingestion Update" do
    test "A failing message gets placed on dead letter queue and discarded" do
      id_for_invalid_ingestion = UUID.uuid4()
      invalid_ingestion = TDG.create_ingestion(%{id: id_for_invalid_ingestion})

      id_for_valid_ingestion = UUID.uuid4()
      valid_ingestion = TDG.create_ingestion(%{id: id_for_valid_ingestion})
      Brook.Event.send(@instance_name, ingestion_update(), __MODULE__, invalid_ingestion)
      Brook.Event.send(@instance_name, ingestion_update(), __MODULE__, valid_ingestion)

      with_mock(Alchemist.IngestionProcessor, start: fn invalid_ingestion -> raise "nope" end) do
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

      with_mock(Alchemist.IngestionProcessor, delete: fn invalid_ingestion -> raise "nope" end) do
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

  describe "Data Extract Start" do
    test "Starts an ingestion processor for the ingestion and creates resulting topics" do
      first_dataset = TDG.create_dataset(%{id: UUID.uuid4()})
      second_dataset = TDG.create_dataset(%{id: UUID.uuid4()})

      ingestion_id = UUID.uuid4()
      ingestion = TDG.create_ingestion(%{id: ingestion_id, targetDatasets: [first_dataset.id, second_dataset.id]})

      Brook.Event.send(@instance_name, dataset_update(), __MODULE__, first_dataset)
      Brook.Event.send(@instance_name, dataset_update(), __MODULE__, second_dataset)
      Brook.Event.send(@instance_name, data_extract_start(), __MODULE__, ingestion)

      eventually(fn ->
        process_started = Alchemist.IngestionSupervisor.is_started?(ingestion.id)

        assert process_started == true
        assert Elsa.topic?(elsa_brokers(), "#{input_topic_prefix()}-#{ingestion.id}")
        assert Elsa.topic?(elsa_brokers(), "#{output_topic_prefix()}-#{first_dataset.id}")
        assert Elsa.topic?(elsa_brokers(), "#{output_topic_prefix()}-#{second_dataset.id}")
      end)
    end

    test "A failing message gets placed on dead letter queue and discarded" do
      id_for_invalid_ingestion = UUID.uuid4()
      id_for_target_dataset = UUID.uuid4()
      invalid_ingestion = TDG.create_ingestion(%{id: id_for_invalid_ingestion, targetDatasets: [id_for_target_dataset]})

      id_for_valid_ingestion = UUID.uuid4()
      valid_ingestion = TDG.create_ingestion(%{id: id_for_valid_ingestion})
      allow(Alchemist.IngestionSupervisor.is_started?(id_for_invalid_ingestion), exec: fn _ -> raise "nope" end)

      Brook.Event.send(@instance_name, data_extract_start(), __MODULE__, invalid_ingestion)
      Brook.Event.send(@instance_name, ingestion_update(), __MODULE__, valid_ingestion)

      eventually(fn ->
        cached_ingestion_id =
          case Brook.ViewState.get(@instance_name, :ingestions, id_for_valid_ingestion) do
            {:ok, %{id: id}} -> id
            _ -> nil
          end

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

        assert cached_ingestion_id != nil
        assert cached_ingestion_id == id_for_valid_ingestion
        assert 1 == length(failed_messages)
      end)
    end
  end
end
