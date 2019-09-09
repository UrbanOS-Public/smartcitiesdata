defmodule DiscoveryApi.Data.ModelTest do
  use ExUnit.Case
  use Placebo
  alias DiscoveryApi.Data.{Model, Persistence}
  alias DiscoveryApi.Test.Helper

  test "Dataset saves empty list of keywords to redis" do
    dataset = Helper.sample_model() |> Map.put(:keywords, nil)
    allow(Persistence.persist(any(), any()), return: {:ok, "good"})

    Model.save(dataset)

    %{keywords: actual_keywords} = capture(Persistence.persist(any(), any()), 2)

    assert [] == actual_keywords
  end

  test "dataset last_updated_date is retrieved from redis" do
    expected_date = DateTime.utc_now()
    allow(Persistence.get(any()), return: {:last_updated_date, expected_date})

    actual_date = Model.get_last_updated_date("123")
    assert expected_date = actual_date
  end

  test "dataset usage metrics are retrieved from redis" do
    keys = ["smart_registry:queries:count:123", "smart_registry:downloads:count:123"]
    allow(Persistence.get_keys("smart_registry:*:count:123"), return: keys)
    allow(Persistence.get_many(keys), return: ["7", "9"])

    expected = %{:downloads => "9", :queries => "7"}
    actual_metrics = Model.get_count_maps("123")
    assert actual_metrics == expected
  end

  test "successfully generate dataset for given dataset_id" do
    dataset = Helper.sample_model()
    expected_date = DateTime.to_iso8601(DateTime.utc_now())
    json_string_dataset = dataset |> Map.from_struct() |> Jason.encode!()
    dataset = %{dataset | lastUpdatedDate: expected_date}
    dataset = %{dataset | downloads: "9"}
    dataset = %{dataset | queries: "7"}

    count_keys = [
      "smart_registry:queries:count:#{dataset.id}",
      "smart_registry:downloads:count:#{dataset.id}"
    ]

    count_values = ["7", "9"]

    allow(Persistence.get("discovery-api:model:#{dataset.id}"), return: json_string_dataset)

    allow(Persistence.get("discovery-api:stats:#{dataset.id}"), return: ~s({"completeness": 0.95}))

    allow(Persistence.get("forklift:last_insert_date:#{dataset.id}"),
      return: expected_date
    )

    allow(Persistence.get_keys("smart_registry:*:count:#{dataset.id}"), return: count_keys)
    allow(Persistence.get_many(count_keys), return: count_values)

    actual_dataset = Model.get(dataset.id)
    assert actual_dataset == dataset
  end

  describe "additional model fields are added" do
    test "get/1" do
      cam = generate_model_return("Cam", ~D(1995-10-20), "ingest")

      allow(Persistence.get("forklift:last_insert_date:Cam"), return: "2019-06-27T00:00:00.000000Z")
      allow(Persistence.get("discovery-api:model:Cam"), return: cam)
      allow(Persistence.get(is(fn arg -> String.starts_with?(arg, "discovery-api:stats:") end)), return: nil)
      allow(Persistence.get_keys(any()), return: [])

      result = Model.get("Cam")
      assert result.lastUpdatedDate == "2019-06-27T00:00:00.000000Z"
    end

    test "get_many/1" do
      paul = generate_model_return("Paul", ~D(1970-01-01), "remote")
      richard = generate_model_return("Richard", ~D(2001-09-09), "ingest")

      allow(Persistence.get(is(fn arg -> String.starts_with?(arg, "discovery-api:stats:") end)), return: nil)
      allow(Persistence.get_keys(any()), return: [])
      allow(Persistence.get("forklift:last_insert_date:Paul"), return: "2019-07-27T00:00:00.000000Z")
      allow(Persistence.get("forklift:last_insert_date:Richard"), return: "2019-08-27T00:00:00.000000Z")
      allow(Persistence.get_many(any()), return: [paul, richard])

      results = Model.get_all(["Paul", "Richard"])
      assert List.first(results).lastUpdatedDate == "2019-07-27T00:00:00.000000Z"
      assert List.last(results).lastUpdatedDate == "2019-08-27T00:00:00.000000Z"
    end
  end

  defp generate_model_return(id, date, sourceType) do
    Helper.sample_model(%{
      description: "#{id}-description",
      fileTypes: ["csv"],
      id: id,
      name: "#{id}-name",
      title: "#{id}-title",
      modifiedDate: "#{date}",
      organization: "#{id} Co.",
      keywords: ["#{id} keywords"],
      sourceType: sourceType,
      organizationDetails: %{
        orgTitle: "#{id}-org-title",
        orgName: "#{id}-org-name",
        logoUrl: "#{id}-org.png"
      },
      private: false
    })
    |> Map.from_struct()
    |> Jason.encode!()
  end
end
