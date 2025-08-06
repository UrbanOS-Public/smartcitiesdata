defmodule Valkyrie.Event.EventHandlerTest do
  use ExUnit.Case
  use Divo
  import Mock
  use Properties, otp_app: :valkyrie

  import SmartCity.TestHelper
  import SmartCity.Event
  alias SmartCity.TestDataGenerator, as: TDG
  alias DeadLetter

  @instance_name Valkyrie.instance_name()
  getter(:elsa_brokers, generic: true)
  getter(:input_topic_prefix, generic: true)

  describe "Data Ingest Start" do
    test "A failing message gets placed on dead letter queue and discarded" do
      id_for_invalid_target_dataset = UUID.uuid4()
      invalid_ingestion = TDG.create_ingestion(%{targetDatasets: [id_for_invalid_target_dataset]})

      id_for_valid_dataset = UUID.uuid4()
      valid_dataset = TDG.create_dataset(%{id: id_for_valid_dataset})

      allow(Brook.get!(@instance_name, :datasets, id_for_invalid_target_dataset), exec: fn _ -> raise "nope" end)

      Brook.Event.send(@instance_name, data_ingest_start(), __MODULE__, invalid_ingestion)
      Brook.Event.send(@instance_name, dataset_update(), __MODULE__, valid_dataset)

      eventually(fn ->
        Brook.ViewState.get_all(@instance_name, :datasets)

        cached_dataset_id =
          case Brook.ViewState.get(@instance_name, :datasets, id_for_valid_dataset) do
            {:ok, %{id: id}} -> id
            _ -> nil
          end

        failed_messages =
          Elsa.Fetch.fetch(elsa_brokers(), "dead-letters")
          |> elem(2)
          |> Enum.filter(fn message ->
            actual = Jason.decode!(message.value)

            case actual["original_message"] do
              %{"targetDatasets" => message_target_datasets} ->
                Enum.member?(message_target_datasets, id_for_invalid_target_dataset)

              _ ->
                false
            end
          end)

        assert cached_dataset_id != nil
        assert cached_dataset_id == id_for_valid_dataset
        assert 1 == length(failed_messages)
      end)
    end
  end

  describe "Dataset Update" do
    test "A failing message gets placed on dead letter queue and discarded" do
      id_for_invalid_dataset = UUID.uuid4()
      invalid_dataset = TDG.create_dataset(%{id: id_for_invalid_dataset})

      id_for_valid_dataset = UUID.uuid4()
      valid_dataset = TDG.create_dataset(%{id: id_for_valid_dataset})
      allow(Valkyrie.DatasetSupervisor.is_started?(id_for_invalid_dataset), exec: fn _ -> raise "nope" end)

      Brook.Event.send(@instance_name, dataset_update(), __MODULE__, invalid_dataset)
      Brook.Event.send(@instance_name, dataset_update(), __MODULE__, valid_dataset)

      eventually(fn ->
        cached_dataset_id =
          case Brook.ViewState.get(@instance_name, :datasets, id_for_valid_dataset) do
            {:ok, %{id: id}} -> id
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

        assert cached_dataset_id != nil
        assert cached_dataset_id == id_for_valid_dataset
        assert 1 == length(failed_messages)
      end)
    end
  end

  describe "Dataset Delete" do
    test "A failing message gets placed on dead letter queue and discarded" do
      id_for_invalid_dataset = UUID.uuid4()
      invalid_dataset = TDG.create_dataset(%{id: id_for_invalid_dataset})

      id_for_valid_dataset = UUID.uuid4()
      valid_dataset = TDG.create_dataset(%{id: id_for_valid_dataset})
      allow(Valkyrie.DatasetProcessor.delete(id_for_invalid_dataset), exec: fn _ -> raise "nope" end)

      Brook.Event.send(@instance_name, dataset_delete(), __MODULE__, invalid_dataset)
      Brook.Event.send(@instance_name, dataset_update(), __MODULE__, valid_dataset)

      eventually(fn ->
        cached_dataset_id =
          case Brook.ViewState.get(@instance_name, :datasets, id_for_valid_dataset) do
            {:ok, %{id: id}} -> id
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

        assert cached_dataset_id != nil
        assert cached_dataset_id == id_for_valid_dataset
        assert 1 == length(failed_messages)
      end)
    end
  end

  describe "Data Extract Start" do
    test "Starts a dataset processor for each target dataset in the ingestion" do
      first_dataset = TDG.create_dataset(%{id: UUID.uuid4()})
      second_dataset = TDG.create_dataset(%{id: UUID.uuid4()})

      ingestion_id = UUID.uuid4()
      ingestion = TDG.create_ingestion(%{id: ingestion_id, targetDatasets: [first_dataset.id, second_dataset.id]})

      Brook.Event.send(@instance_name, dataset_update(), __MODULE__, first_dataset)
      Brook.Event.send(@instance_name, dataset_update(), __MODULE__, second_dataset)
      Brook.Event.send(@instance_name, data_extract_start(), __MODULE__, ingestion)

      eventually(fn ->
        first_process = Valkyrie.DatasetSupervisor.is_started?(first_dataset.id)
        second_process = Valkyrie.DatasetSupervisor.is_started?(second_dataset.id)

        assert first_process and second_process
      end)
    end

    test "A failing message gets placed on dead letter queue and discarded" do
      id_for_invalid_ingestion = UUID.uuid4()
      id_for_target_dataset = UUID.uuid4()
      invalid_ingestion = TDG.create_ingestion(%{id: id_for_invalid_ingestion, targetDatasets: [id_for_target_dataset]})

      id_for_valid_dataset = UUID.uuid4()
      valid_dataset = TDG.create_dataset(%{id: id_for_valid_dataset})
      allow(Brook.get!(@instance_name, :datasets, id_for_target_dataset), exec: fn _, _, _ -> raise "nope" end)

      Brook.Event.send(@instance_name, data_extract_start(), __MODULE__, invalid_ingestion)
      Brook.Event.send(@instance_name, dataset_update(), __MODULE__, valid_dataset)

      eventually(fn ->
        cached_dataset_id =
          case Brook.ViewState.get(@instance_name, :datasets, id_for_valid_dataset) do
            {:ok, %{id: id}} -> id
            _ -> nil
          end

        failed_messages =
          Elsa.Fetch.fetch(elsa_brokers(), "dead-letters")
          |> elem(2)
          |> Enum.filter(fn message ->
            actual = Jason.decode!(message.value)

            case actual["original_message"] do
              %{"id" => message_dataset_id} ->
                message_dataset_id == id_for_invalid_ingestion

              _ ->
                false
            end
          end)

        assert cached_dataset_id != nil
        assert cached_dataset_id == id_for_valid_dataset
        assert 1 == length(failed_messages)
      end)
    end
  end
end
