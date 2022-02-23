defmodule Andi.Services.IngestionStore do
    @moduledoc """
    An Abstraction that handle the specifics of the Brook View state for andi ingestion.
    """
  
    @instance_name Andi.instance_name()
  
    @collection :ingestion
    @collection_ingested_time :ingested_time
  
    # Brook View State for collection dataset
  
    def update(%SmartCity.Ingestion{} = ingestion) do
      Brook.ViewState.merge(@collection, ingestion.id, ingestion)
    end
  
    def get(id) do
      Brook.get(@instance_name, @collection, id)
    end
  
    def get_all() do
      Brook.get_all_values(@instance_name, @collection)
    end
  
    def get_all!() do
      Brook.get_all_values!(@instance_name, @collection)
    end
  
    def delete(id) do
      Brook.ViewState.delete(@collection, id)
    end
  
    # Brook View State for collection ingested time
  
    def get_ingested_time!(id) do
      Brook.get!(@instance_name, @collection_ingested_time, id)
    end
  
    def get_all_ingested_time!() do
      Brook.get_all_values!(@instance_name, @collection_ingested_time)
    end
  
    def delete_ingested_time(id) do
      Brook.ViewState.delete(@collection_ingested_time, id)
    end
  end
  