defmodule Reaper.EventHandlerTest do
  use ExUnit.Case
  use Divo
  use Placebo
  use Properties, otp_app: :reaper

  import SmartCity.TestHelper
  import SmartCity.Event
  alias SmartCity.TestDataGenerator, as: TDG
  alias DeadLetter

  @instance_name Reaper.instance_name()
  getter(:elsa_brokers, generic: true)

  describe "Ingestion Update" do
    test "A failing message gets placed on dead letter queue and discarded" do
      id_for_invalid_ingestion = UUID.uuid4()
      invalid_ingestion = TDG.create_ingestion(%{id: id_for_invalid_ingestion})

      id_for_valid_ingestion = UUID.uuid4()
      valid_ingestion = TDG.create_ingestion(%{id: id_for_valid_ingestion})
      allow(Reaper.Event.Handlers.IngestionUpdate.handle(invalid_ingestion), exec: fn _ -> raise "nope" end)

      Brook.Event.send(@instance_name, ingestion_update(), __MODULE__, invalid_ingestion)
      Brook.Event.send(@instance_name, ingestion_update(), __MODULE__, valid_ingestion)

      eventually(fn ->
        {:ok, %{"ingestion" => cached_ingestion}} =
          Brook.ViewState.get(@instance_name, :extractions, id_for_valid_ingestion)

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

        assert cached_ingestion.id == id_for_valid_ingestion
        assert 1 == length(failed_messages)
      end)
    end
  end

  describe "Ingestion Delete" do
    test "A failing message gets placed on dead letter queue and discarded" do
      id_for_invalid_ingestion = UUID.uuid4()
      invalid_ingestion = TDG.create_ingestion(%{id: id_for_invalid_ingestion})

      id_for_valid_ingestion = UUID.uuid4()
      valid_ingestion = TDG.create_ingestion(%{id: id_for_valid_ingestion})
      allow(Reaper.Event.Handlers.IngestionDelete.handle(invalid_ingestion), exec: fn _ -> raise "nope" end)

      Brook.Event.send(@instance_name, ingestion_delete(), __MODULE__, invalid_ingestion)
      Brook.Event.send(@instance_name, ingestion_update(), __MODULE__, valid_ingestion)

      eventually(fn ->
        {:ok, %{"ingestion" => cached_ingestion}} =
          Brook.ViewState.get(@instance_name, :extractions, id_for_valid_ingestion)

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

        assert cached_ingestion.id == id_for_valid_ingestion
        assert 1 == length(failed_messages)
      end)
    end
  end

  describe "Data Extract Start" do
    test "A failing message gets placed on dead letter queue and discarded" do
      id_for_invalid_ingestion = UUID.uuid4()
      invalid_ingestion = TDG.create_ingestion(%{id: id_for_invalid_ingestion})

      id_for_valid_ingestion = UUID.uuid4()
      valid_ingestion = TDG.create_ingestion(%{id: id_for_valid_ingestion})
      allow(Reaper.Collections.Extractions.is_enabled?(id_for_invalid_ingestion), exec: fn _ -> raise "nope" end)

      Brook.Event.send(@instance_name, data_extract_start(), __MODULE__, invalid_ingestion)
      Brook.Event.send(@instance_name, ingestion_update(), __MODULE__, valid_ingestion)

      eventually(fn ->
        cached_ingestion = case Brook.ViewState.get(@instance_name, :extractions, id_for_valid_ingestion) do
          {:ok, %{"ingestion" => ing}} -> ing
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

        assert cached_ingestion != nil
        assert cached_ingestion.id == id_for_valid_ingestion
        assert 1 == length(failed_messages)
      end)
    end
  end

  describe "Data Extract End" do
    test "A failing message gets placed on dead letter queue and discarded" do
      id_for_invalid_ingestion = UUID.uuid4()

      data = %{
        "dataset_id" => UUID.uuid4(),
        "extract_start_unix" => "",
        "ingestion_id" => id_for_invalid_ingestion,
        "msgs_extracted" => ""
      }

      id_for_valid_ingestion = UUID.uuid4()
      valid_ingestion = TDG.create_ingestion(%{id: id_for_valid_ingestion})

      allow(Reaper.Collections.Extractions.update_last_fetched_timestamp(id_for_invalid_ingestion),
        exec: fn _ -> raise "nope" end
      )

      Brook.Event.send(@instance_name, data_extract_end(), __MODULE__, data)
      Brook.Event.send(@instance_name, ingestion_update(), __MODULE__, valid_ingestion)

      eventually(fn ->
        cached_ingestion = case Brook.ViewState.get(@instance_name, :extractions, id_for_valid_ingestion) do
          {:ok, %{"ingestion" => ing}} -> ing
          _ -> nil
        end

        failed_messages =
          Elsa.Fetch.fetch(elsa_brokers(), "dead-letters")
          |> elem(2)
          |> Enum.filter(fn message ->
            actual = Jason.decode!(message.value)
            case actual["original_message"] do
              %{"ingestion_id" => message_ingestion_id} ->
                message_ingestion_id == id_for_invalid_ingestion

              _ ->
                false
            end
          end)

        assert cached_ingestion != nil
        assert cached_ingestion.id == id_for_valid_ingestion
        assert 1 == length(failed_messages)
      end)
    end
  end

  describe "Dataset Delete" do
    test "A failing message gets placed on dead letter queue and discarded" do
      id_for_invalid_dataset = UUID.uuid4()

      invalid_dataset = TDG.create_dataset(%{id: id_for_invalid_dataset})

      id_for_valid_ingestion = UUID.uuid4()
      valid_ingestion = TDG.create_ingestion(%{id: id_for_valid_ingestion})

      allow(Brook.ViewState.get_all(@instance_name, :extractions),
        exec: fn _ -> raise "nope" end
      )

      Brook.Event.send(@instance_name, dataset_delete(), __MODULE__, invalid_dataset)
      Brook.Event.send(@instance_name, ingestion_update(), __MODULE__, valid_ingestion)

      eventually(fn ->
        cached_ingestion = case Brook.ViewState.get(@instance_name, :extractions, id_for_valid_ingestion) do
          {:ok, %{"ingestion" => ing}} -> ing
          _ -> nil
        end

        failed_messages =
          Elsa.Fetch.fetch(elsa_brokers(), "dead-letters")
          |> elem(2)
          |> Enum.filter(fn message ->
            actual = Jason.decode!(message.value)
            case actual["original_message"] do
              %{"id" => message_dataset_id} ->
                message_dataset_id == id_for_invalid_dataset

              _ ->
                false
            end
          end)

        assert cached_ingestion != nil
        assert cached_ingestion.id == id_for_valid_ingestion
        assert 1 == length(failed_messages)
      end)
    end
  end
end
