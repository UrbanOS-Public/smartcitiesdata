defmodule Forklift.Datasets.DatasetHandler do
  @moduledoc """
  Handler for dataset schema updates and starting and stopping dataset ingestion
  """
  alias SmartCity.Dataset
  alias Forklift.Datasets.{DatasetSchema, DatasetSupervisor}
  alias Forklift.TopicManager
  alias Forklift.Tables.TableCreator
  require Logger

  def start_dataset_ingest(%DatasetSchema{} = schema) do
    topics = TopicManager.setup_topics(schema)

    start_options = [
      schema: schema,
      input_topic: topics.input_topic
    ]

    stop_dataset_ingest(schema)
    DynamicSupervisor.start_child(Forklift.Dynamic.Supervisor, {DatasetSupervisor, start_options})
  end

  def stop_dataset_ingest(%DatasetSchema{} = schema) do
    name = DatasetSupervisor.name(schema)

    case Process.whereis(name) do
      nil -> :ok
      pid -> DynamicSupervisor.terminate_child(Forklift.Dynamic.Supervisor, pid)
    end
  end

  def create_table_for_dataset(dataset) do
    create_table_for_dataset = Dataset.is_ingest?(dataset) || Dataset.is_stream?(dataset)

    if create_table_for_dataset do
      TableCreator.create_table(dataset)
    end
  end
end
