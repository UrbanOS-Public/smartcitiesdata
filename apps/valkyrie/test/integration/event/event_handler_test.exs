defmodule Valkyrie.Event.EventHandlerTest do
  use ExUnit.Case
  use Divo
  use Placebo
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
      invalid_ingestion = TDG.create_ingestion(%{targetDataset: id_for_invalid_target_dataset})

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
              %{"targetDataset" => message_target_dataset} ->
                message_target_dataset == id_for_invalid_target_dataset

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

  describe "Data Standardization End" do
    test "A failing message gets placed on dead letter queue and discarded" do
      id_for_invalid_data = UUID.uuid4()
      data = %{"dataset_id" => id_for_invalid_data}

      id_for_valid_dataset = UUID.uuid4()
      valid_dataset = TDG.create_dataset(%{id: id_for_valid_dataset})
      allow(Valkyrie.DatasetProcessor.stop(id_for_invalid_data), exec: fn _ -> raise "nope" end)

      Brook.Event.send(@instance_name, data_standardization_end(), __MODULE__, data)
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
              %{"dataset_id" => message_dataset_id} ->
                message_dataset_id == id_for_invalid_data

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
end
