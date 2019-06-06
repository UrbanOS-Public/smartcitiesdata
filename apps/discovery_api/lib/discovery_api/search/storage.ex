defmodule DiscoveryApi.Search.Storage do
  @moduledoc """
  Optimize searches by looking up searched words in a table where the searched word is the key and the value is the dataset.
  """
  use GenServer

  alias DiscoveryApi.Data.Model

  @all_punctuation ~r/[^\w\s]/

  @spec index(%DiscoveryApi.Data.Model{}) :: :ok
  def index(model) do
    GenServer.cast(__MODULE__, {:index, model})
  end

  @spec search(String.t()) :: list(%DiscoveryApi.Data.Model{})
  def search(query) do
    query
    |> String.split()
    |> Enum.map(&remove_punctuation/1)
    |> Enum.map(&get_dataset_ids_for_word/1)
    |> get_intersection_of_datasets()
    |> Model.get_all()
  end

  def start_link(_args \\ []) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_args) do
    :ets.new(__MODULE__, [:bag, :protected, :named_table, {:read_concurrency, true}])

    {:ok, []}
  end

  def handle_cast({:index, model}, state) do
    delete_all_for_model(model)

    ([model.title, model.description, model.organization] ++ model.keywords)
    |> Enum.map(&String.downcase/1)
    |> Enum.map(&String.split/1)
    |> List.flatten()
    |> Enum.uniq()
    |> Enum.map(&remove_punctuation/1)
    |> Enum.each(&save_word(&1, model.id))

    {:noreply, state}
  end

  def handle_cast(:clear, state) do
    :ets.match_delete(__MODULE__, {:_, :_})
    {:noreply, state}
  end

  defp delete_all_for_model(model) do
    :ets.match_delete(__MODULE__, {:_, model.id})
  end

  defp remove_punctuation(word) do
    Regex.replace(@all_punctuation, word, "")
  end

  defp get_dataset_ids_for_word(word) do
    __MODULE__
    |> :ets.lookup(word)
    |> Enum.map(fn {_word, dataset_id} -> dataset_id end)
  end

  defp get_intersection_of_datasets(dataset_ids) do
    dataset_ids
    |> Enum.map(&MapSet.new/1)
    |> Enum.reduce(&MapSet.intersection(&1, &2))
  end

  defp save_word(word, id) do
    :ets.insert(__MODULE__, {word, id})
  end
end
