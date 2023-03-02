defmodule Forklift.Event.EventHandlerTest do
  use ExUnit.Case
  use Divo
  use Placebo
  use Properties, otp_app: :forklift

  import SmartCity.TestHelper
  import SmartCity.Event
  alias SmartCity.TestDataGenerator, as: TDG
  alias DeadLetter

  @instance_name Forklift.instance_name()
  getter(:elsa_brokers, generic: true)

  describe "Ingestion Update" do
    test "A failing message gets placed on dead letter queue and discarded" do
      IO.inspect("A failing message gets placed on dead letter queue and discarded", label: "Ryan")
      id_for_invalid_ingestion = UUID.uuid4()
      id_for_invalid_dataset = UUID.uuid4()
      invalid_ingestion = TDG.create_ingestion(%{id: id_for_invalid_ingestion, targetDataset: id_for_invalid_dataset})

      id_for_valid_dataset = UUID.uuid4()
      valid_dataset = TDG.create_dataset(%{id: id_for_valid_dataset, technical: %{sourceType: "ingest"}})
      allow(Forklift.Datasets.get!(id_for_invalid_dataset), exec: fn _ -> raise "nope" end)

      Brook.Event.send(@instance_name, data_ingest_start(), __MODULE__, invalid_ingestion)
      Brook.Event.send(@instance_name, dataset_update(), __MODULE__, valid_dataset)

      eventually(fn ->
        cached_dataset = Forklift.Datasets.get!(id_for_valid_dataset)

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

        assert cached_dataset != nil
        assert cached_dataset.id == id_for_valid_dataset
        assert 1 == length(failed_messages)
      end)
    end
  end

  describe "Dataset Update" do
    test "A failing message gets placed on dead letter queue and discarded" do
      IO.inspect("Dataset Update - A failing message gets placed on dead letter queue and discarded", label: "Ryan")
      id_for_invalid_dataset = UUID.uuid4()
      invalid_dataset = TDG.create_dataset(%{id: id_for_invalid_dataset, technical: %{sourceType: "ingest"}})

      id_for_valid_dataset = UUID.uuid4()
      valid_dataset = TDG.create_dataset(%{id: id_for_valid_dataset, technical: %{sourceType: "ingest"}})
      allow(Forklift.Datasets.update(invalid_dataset), exec: fn _ -> raise "nope" end)

      Brook.Event.send(@instance_name, dataset_update(), __MODULE__, invalid_dataset)
      Brook.Event.send(@instance_name, dataset_update(), __MODULE__, valid_dataset)

      eventually(fn ->
        cached_dataset = Forklift.Datasets.get!(id_for_valid_dataset)

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

        assert cached_dataset != nil
        assert cached_dataset.id == id_for_valid_dataset
        assert 1 == length(failed_messages)
      end)
    end
  end

  describe "Dataset Ingest End" do
    test "A failing message gets placed on dead letter queue and discarded" do
      IO.inspect("Dataset Ingest End - A failing message gets placed on dead letter queue and discarded", label: "Ryan")
      id_for_invalid_dataset = UUID.uuid4()
      invalid_dataset = TDG.create_dataset(%{id: id_for_invalid_dataset})

      id_for_valid_dataset = UUID.uuid4()
      valid_dataset = TDG.create_dataset(%{id: id_for_valid_dataset, technical: %{sourceType: "ingest"}})
      allow(Forklift.DataReaderHelper.terminate(invalid_dataset), exec: fn _ -> raise "nope" end)

      Brook.Event.send(@instance_name, data_ingest_end(), __MODULE__, invalid_dataset)
      Brook.Event.send(@instance_name, dataset_update(), __MODULE__, valid_dataset)

      eventually(fn ->
        cached_dataset = Forklift.Datasets.get!(id_for_valid_dataset)

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

        assert cached_dataset != nil
        assert cached_dataset.id == id_for_valid_dataset
        assert 1 == length(failed_messages)
      end)
    end
  end

  #
  describe "Migration Last Insert Date Start" do
    test "A failing message gets placed on dead letter queue and discarded" do
      IO.inspect("Migration Last Insert Date Start - A failing message gets placed on dead letter queue and discarded",
        label: "Ryan"
      )

      id_for_fake_event = UUID.uuid4()

      id_for_valid_dataset = UUID.uuid4()
      valid_dataset = TDG.create_dataset(%{id: id_for_valid_dataset, technical: %{sourceType: "ingest"}})
      allow(Redix.command!(:redix, ["KEYS", "forklift:last_insert_date:*"]), exec: fn _ -> raise "nope" end)

      Brook.Event.send(@instance_name, "migration:last_insert_date:start", __MODULE__, %{fake_event: id_for_fake_event})
      Brook.Event.send(@instance_name, dataset_update(), __MODULE__, valid_dataset)

      eventually(fn ->
        cached_dataset = Forklift.Datasets.get!(id_for_valid_dataset)

        failed_messages =
          Elsa.Fetch.fetch(elsa_brokers(), "dead-letters")
          |> elem(2)
          |> Enum.filter(fn message ->
            actual = Jason.decode!(message.value)

            case actual["original_message"] do
              %{"data" => %{"fake_event" => fake_id}} ->
                fake_id == id_for_fake_event

              _ ->
                false
            end
          end)

        assert cached_dataset != nil
        assert cached_dataset.id == id_for_valid_dataset
        assert 1 == length(failed_messages)
      end)
    end
  end

  describe "Dataset Delete Start" do
    test "A failing message gets placed on dead letter queue and discarded" do
      IO.inspect("Dataset Delete Start - A failing message gets placed on dead letter queue and discarded",
        label: "Ryan"
      )

      id_for_invalid_dataset = UUID.uuid4()
      invalid_dataset = TDG.create_dataset(%{id: id_for_invalid_dataset})

      id_for_valid_dataset = UUID.uuid4()
      valid_dataset = TDG.create_dataset(%{id: id_for_valid_dataset, technical: %{sourceType: "ingest"}})
      allow(Forklift.DataReaderHelper.terminate(invalid_dataset), exec: fn _ -> raise "nope" end)

      Brook.Event.send(@instance_name, dataset_delete(), __MODULE__, invalid_dataset)
      Brook.Event.send(@instance_name, dataset_update(), __MODULE__, valid_dataset)

      eventually(fn ->
        cached_dataset = Forklift.Datasets.get!(id_for_valid_dataset)

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

        assert cached_dataset != nil
        assert cached_dataset.id == id_for_valid_dataset
        assert 1 == length(failed_messages)
      end)
    end
  end

  describe "Data Extract End" do
    test "A failing message gets placed on dead letter queue and discarded" do
      IO.inspect("Data Extract End - A failing message gets placed on dead letter queue and discarded", label: "Ryan")
      id_for_invalid_dataset = UUID.uuid4()

      invalid_data = %{
        "dataset_id" => id_for_invalid_dataset,
        "extract_start_unix" => "",
        "ingestion_id" => "",
        "msgs_extracted" => ""
      }

      id_for_valid_dataset = UUID.uuid4()
      valid_dataset = TDG.create_dataset(%{id: id_for_valid_dataset, technical: %{sourceType: "ingest"}})
      allow(Forklift.Datasets.get!(id_for_invalid_dataset), exec: fn _ -> raise "nope" end)

      Brook.Event.send(@instance_name, data_extract_end(), __MODULE__, invalid_data)
      Brook.Event.send(@instance_name, dataset_update(), __MODULE__, valid_dataset)

      eventually(fn ->
        cached_dataset = Forklift.Datasets.get!(id_for_valid_dataset)

        failed_messages =
          Elsa.Fetch.fetch(elsa_brokers(), "dead-letters")
          |> elem(2)
          |> Enum.filter(fn message ->
            actual = Jason.decode!(message.value)

            case actual["original_message"] do
              %{"dataset_id" => message_dataset_id} ->
                message_dataset_id == id_for_invalid_dataset

              _ ->
                false
            end
          end)

        assert cached_dataset != nil
        assert cached_dataset.id == id_for_valid_dataset
        assert 1 == length(failed_messages)
      end)
    end
  end
end
