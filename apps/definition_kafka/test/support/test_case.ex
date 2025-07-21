defmodule DefinitionKafka.TestCase do
  use ExUnit.CaseTemplate

  using do
    quote do
      import Mox
      alias SmartCitiesData.Kafka.Topic
      alias SmartCitiesData.Protocol.Destination
      alias Destination.Context
      alias SmartCitiesData.Definition.Dictionary
    end
  end
end
