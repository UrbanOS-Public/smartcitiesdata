defmodule DiscoveryApi.Data.DatasetRetrieverTest do
  use ExUnit.Case
  use Placebo
  alias DiscoveryApi.Data.Retriever

  describe "get_datasets" do
    test "returns list of datasets" do
      expected = [
        %DiscoveryApi.Data.Dataset{
          description: "Dataset 1 description",
          fileTypes: ["csv", "pdf"],
          id: 1,
          modified: 1_546_466_404_117,
          organization: "Org 1",
          keywords: ["cat", "dog"],
          title: "Dataset 1"
        }
      ]

      allow DiscoveryApi.Data.Dataset.get_all(), return: expected
      assert expected == Retriever.get_datasets()
    end
  end
end
