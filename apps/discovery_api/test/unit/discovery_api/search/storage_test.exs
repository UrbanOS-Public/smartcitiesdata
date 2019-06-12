defmodule DiscoveryApi.Search.StorageTest do
  use ExUnit.Case
  use Placebo

  alias DiscoveryApi.Test.Helper
  alias DiscoveryApi.Search.Storage
  alias DiscoveryApi.Data.Model

  setup do
    GenServer.cast(DiscoveryApi.Search.Storage, :clear)
    :ok
  end

  describe "index/1" do
    test "should store index for title in ets table" do
      model = Helper.sample_model(%{title: "This is the best"})

      Storage.index(model)

      assert_words_indexed?(model.title, model.id)
    end

    test "should store index for description in ets table" do
      model = Helper.sample_model(%{description: "Descriptions are awesome"})

      Storage.index(model)

      assert_words_indexed?(model.description, model.id)
    end

    test "should store index for organization in ets table" do
      model = Helper.sample_model(%{organization: "Organizations are some amazing stuff"})

      Storage.index(model)

      assert_words_indexed?(model.organization, model.id)
    end

    test "should store index keywords in ets table" do
      model = Helper.sample_model(%{keywords: ["one", "two", "three", "highways"]})

      Storage.index(model)

      assert_words_indexed?(model.keywords, model.id)
    end

    test "should remove all punctuation from words" do
      model = Helper.sample_model(%{title: "Hello, world", description: "Jerks.", organization: "Hey-Ya"})

      Storage.index(model)

      assert_words_indexed?("hello world", model.id)
      assert_words_indexed?("jerks", model.id)
      assert_words_indexed?("heyya", model.id)
    end

    test "should remove all entries for dataset prior to indexing" do
      model1 = Helper.sample_model(%{title: "I love science"})
      model2 = Helper.sample_model(%{id: model1.id, title: "bicycle helmets"})

      allow Model.get_all(any()), return: :doesnt_matter

      Storage.index(model1)
      Storage.index(model2)

      assert_words_indexed?("bicycle", model2.id)

      Storage.search("science")

      arg = capture(Model.get_all(any()), 1)
      assert arg == MapSet.new()
    end
  end

  describe "search/1" do
    test "search should return all models that match search string" do
      model1 = Helper.sample_model(%{title: "this is the title"})
      model2 = Helper.sample_model(%{description: "title is the best"})
      model3 = Helper.sample_model(%{organization: "fun stuff"})
      model4 = Helper.sample_model(%{keywords: ["best"]})

      allow Model.get_all(any()), return: [model2]

      Storage.index(model1)
      Storage.index(model2)
      Storage.index(model3)
      Storage.index(model4)

      assert_words_indexed?("best", model4.id)

      result = Storage.search("best, Title")

      ids = capture(Model.get_all(any()), 1)
      assert ids == MapSet.new([model2.id])
      assert result == [model2]
    end
  end

  defp assert_words_indexed?(string, id) when is_binary(string) do
    string
    |> String.downcase()
    |> String.split()
    |> assert_words_indexed?(id)
  end

  defp assert_words_indexed?(words, id) when is_list(words) do
    Patiently.wait_for!(
      fn ->
        Enum.all?(words, fn word -> {word, id} in :ets.lookup(DiscoveryApi.Search.Storage, word) end)
      end,
      dwell: 100,
      max_tries: 20
    )
  end
end
