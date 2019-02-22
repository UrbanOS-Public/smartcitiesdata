defmodule DiscoveryApiWeb.DatasetDetailControllerTest do
  use DiscoveryApiWeb.ConnCase
  use Placebo
  alias DiscoveryApi.Data.Dataset

  describe "fetch dataset detail" do
    test "retreives dataset from retriever" do
      # id = "123"
      # dataset = %Dataset{id: id, title: "The Title"}
      # expect(DiscoveryApi.Data.Retriever.get_dataset(id), return: dataset)

      # actual = get(conn, "/v1/api/dataset/#{id}") |> json_response(200)

      # assert dataset == actual
    end
  end
end
