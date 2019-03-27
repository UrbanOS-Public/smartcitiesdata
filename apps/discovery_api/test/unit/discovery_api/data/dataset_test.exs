defmodule DiscoveryApi.Data.DatasetTest do
  use ExUnit.Case
  use Placebo
  alias DiscoveryApi.Data.Persistence
  alias DiscoveryApi.Test.Helper

  test "Dataset saves empty list of keywords to redis" do
    dataset = Helper.sample_dataset() |> Map.put(:keywords, nil)
    allow(Persistence.persist(any(), any()), return: {:ok, "good"})

    DiscoveryApi.Data.Dataset.save(dataset)

    %{keywords: actual_keywords} = capture(Persistence.persist(any(), any()), 2)

    assert [] == actual_keywords
  end
end
