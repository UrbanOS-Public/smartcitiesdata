defmodule DiscoveryApi.Data.Search.DatasetIndexTest do
  use ExUnit.Case
  use Divo, services: [:redis, :"ecto-postgres", :zookeeper, :kafka, :elasticsearch]
  use DiscoveryApi.ElasticSearchCase

  alias DiscoveryApi.Test.Helper

  alias DiscoveryApi.Search.DatasetIndex, as: DatasetSearchIndex
  alias DiscoveryApi.Data.Model

  describe "create_index/0" do
    test "it creates the datasets index", %{es_indices: %{datasets: index}} do
      assert {:ok, _} = DatasetSearchIndex.delete_index()
      assert {:ok, created} = DatasetSearchIndex.create_index()

      index_name_as_atom = String.to_atom(index.name)
      assert created[index_name_as_atom][:mappings] != %{}
    end
  end

  describe "delete_index/0" do
    test "it deletes the datasets index" do
      assert {:ok, _} = DatasetSearchIndex.delete_index()
      assert {:error, _} = DatasetSearchIndex.get_index()
    end
  end

  describe "get_index/0" do
    test "it gets the datasets index", %{es_indices: %{datasets: index}} do
      assert {:ok, gotten} = DatasetSearchIndex.get_index()

      index_name_as_atom = String.to_atom(index.name)
      assert gotten[index_name_as_atom][:mappings] != %{}
    end
  end

  describe "reset_index/0" do
    test "it resets the datasets index", %{es_indices: %{datasets: index}} do
      assert {:ok, reset} = DatasetSearchIndex.reset_index()

      index_name_as_atom = String.to_atom(index.name)
      assert reset[index_name_as_atom][:mappings] != %{}
    end
  end

  describe "create_index/2" do
    test "given an index name with no options, it creates it" do
      name =
        Faker.Name.first_name()
        |> String.downcase()

      on_exit(fn ->
        DatasetSearchIndex.delete_index(name)
      end)

      assert {:ok, _} = DatasetSearchIndex.create_index(name)
    end

    test "given an invalid index name (must be lowercase) it returns an error" do
      name =
        Faker.Name.first_name()
        |> String.upcase()

      assert {:error, _} = DatasetSearchIndex.create_index(name)
    end

    test "given an index name with some options (mapping) it creates it" do
      name =
        Faker.Name.first_name()
        |> String.downcase()

      name_as_atom = String.to_atom(name)

      options = %{
        mappings: %{
          properties: %{
            title: %{
              type: "keyword",
              index: false
            }
          }
        }
      }

      on_exit(fn ->
        DatasetSearchIndex.delete_index(name)
      end)

      assert {:ok, _} = DatasetSearchIndex.create_index(name, options)
      assert {:ok, index} = DatasetSearchIndex.get_index(name)

      assert options.mappings == index[name_as_atom][:mappings]
    end
  end

  describe "delete_index/1" do
    test "given an index that does not exist, it does not error" do
      name =
        Faker.Name.first_name()
        |> String.downcase()

      assert {:ok, _} = DatasetSearchIndex.delete_index(name)
    end

    test "given an index that does exist, it does delete the index" do
      name =
        Faker.Name.first_name()
        |> String.downcase()

      assert {:ok, _} = DatasetSearchIndex.create_index(name)
      assert {:ok, _} = DatasetSearchIndex.delete_index(name)

      assert {:error, error} = DatasetSearchIndex.get_index(name)

      assert %{type: "index_not_found_exception"} = error
    end

    test "given a failure to delete for some other reason, it returns the error" do
      bypass = Bypass.open()
      reconfigure_es_url("http://localhost:#{bypass.port}")

      name =
        Faker.Name.first_name()
        |> String.downcase()

      Bypass.stub(bypass, "DELETE", "/#{name}", fn conn ->
        Plug.Conn.resp(conn, 500, ~s({"error": "darsh was here"}))
      end)

      assert {:error, _} = DatasetSearchIndex.delete_index(name)
    end
  end

  describe "reset_index/1" do
    test "given an index that does not exist, it builds it" do
      name =
        Faker.Name.first_name()
        |> String.downcase()

      name_as_atom = String.to_atom(name)

      options = %{
        mappings: %{
          properties: %{
            title: %{
              type: "keyword",
              index: false
            }
          }
        }
      }

      on_exit(fn ->
        DatasetSearchIndex.delete_index(name)
      end)

      assert {:ok, _} = DatasetSearchIndex.reset_index(name, options)
      assert {:ok, index} = DatasetSearchIndex.get_index(name)
      assert options.mappings == index[name_as_atom][:mappings]
    end

    test "given an index that exists, it replaces it" do
      name =
        Faker.Name.first_name()
        |> String.downcase()

      name_as_atom = String.to_atom(name)

      existing_options = %{
        mappings: %{
          properties: %{
            title: %{
              type: "keyword",
              index: false
            }
          }
        }
      }

      on_exit(fn ->
        DatasetSearchIndex.delete_index(name)
      end)

      assert {:ok, _} = DatasetSearchIndex.create_index(name, existing_options)
      assert {:ok, existing_index} = DatasetSearchIndex.get_index(name)
      assert existing_options.mappings == existing_index[name_as_atom][:mappings]

      new_options = %{
        mappings: %{
          properties: %{
            name: %{
              type: "keyword",
              index: false
            }
          }
        }
      }

      assert {:ok, _} = DatasetSearchIndex.reset_index(name, new_options)
      assert {:ok, replaced_index} = DatasetSearchIndex.get_index(name)
      assert new_options.mappings == replaced_index[name_as_atom][:mappings]
    end

    test "given a failure to delete for some reason, it returns the error" do
      bypass = Bypass.open()
      reconfigure_es_url("http://localhost:#{bypass.port}")

      name =
        Faker.Name.first_name()
        |> String.downcase()

      Bypass.stub(bypass, "DELETE", "/#{name}", fn conn ->
        Plug.Conn.resp(conn, 500, ~s({"error": "yep"}))
      end)

      assert {:error, _} = DatasetSearchIndex.reset_index(name, %{})
    end

    test "given a failure to create for some reason, it returns the error" do
      bypass = Bypass.open()
      reconfigure_es_url("http://localhost:#{bypass.port}")

      name =
        Faker.Name.first_name()
        |> String.downcase()

      Bypass.stub(bypass, "DELETE", "/#{name}", fn conn ->
        Plug.Conn.resp(conn, 200, "")
      end)

      Bypass.stub(bypass, "PUT", "/#{name}", fn conn ->
        Plug.Conn.resp(conn, 500, ~s({"error": "that's no good"}))
      end)

      assert {:error, _} = DatasetSearchIndex.reset_index(name, %{})
    end
  end

  describe "get/1" do
    test "given an existing dataset, it returns it" do
      dataset = Helper.sample_model()
      atomized_dataset = expected_dataset(dataset)
      assert {:ok, _saved} = DatasetSearchIndex.update(dataset)

      assert {:ok, gotten} = DatasetSearchIndex.get(dataset.id)
      assert atomized_dataset == gotten
    end

    test "given a missing dataset, it returns an error" do
      dataset = Helper.sample_model()

      assert {:error, _} = DatasetSearchIndex.get(dataset.id)
    end
  end

  describe "get_all/0" do
    test "given multiple existing datasets, it returns them" do
      dataset_one = Helper.sample_model()
      dataset_two = Helper.sample_model()

      atomized_dataset_one = expected_dataset(dataset_one)
      atomized_dataset_two = expected_dataset(dataset_two)
      atomized_datasets = [atomized_dataset_one, atomized_dataset_two]

      assert {:ok, _saved} = DatasetSearchIndex.update(dataset_one)
      assert {:ok, _saved} = DatasetSearchIndex.update(dataset_two)

      assert {:ok, atomized_datasets} == DatasetSearchIndex.get_all()
    end

    test "given no existing datasets, it returns an empty list" do
      assert {:ok, []} == DatasetSearchIndex.get_all()
    end

    test "given a search failure it returns an error", %{es_indices: %{datasets: %{name: datasets}}} do
      bypass = Bypass.open()
      reconfigure_es_url("http://localhost:#{bypass.port}")

      Bypass.stub(bypass, "POST", "/#{datasets}/_doc/_search", fn conn ->
        Plug.Conn.resp(conn, 400, ~s({"error": "you think you can beat me?!"}))
      end)

      assert {:error, _} = DatasetSearchIndex.get_all()
    end
  end

  describe "update/1" do
    test "given a new dataset, it creates it in elasticsearch" do
      dataset = Helper.sample_model()
      atomized_dataset = expected_dataset(dataset)

      assert {:ok, _} = DatasetSearchIndex.update(dataset)
      assert {:ok, saved} = DatasetSearchIndex.get(dataset.id)
      assert atomized_dataset == saved
    end

    test "given an existing dataset, it merges the changes in elasticsearch" do
      existing_dataset = Helper.sample_model()
      assert {:ok, _saved} = DatasetSearchIndex.update(existing_dataset)

      original_title = existing_dataset.title
      updated_name = "Look at me, I'm a new name!"
      partial_update = %Model{id: existing_dataset.id, name: updated_name}

      assert {:ok, _} = DatasetSearchIndex.update(partial_update)
      assert {:ok, updated} = DatasetSearchIndex.get(partial_update.id)

      assert %Model{title: ^original_title, name: ^updated_name} = updated
    end

    test "the dataset it updates is immediately searchable (refresh = true)" do
      dataset = Helper.sample_model()
      atomized_dataset = expected_dataset(dataset)

      assert {:ok, _saved} = DatasetSearchIndex.update(dataset)

      assert {:ok, [atomized_dataset]} == DatasetSearchIndex.get_all()
    end

    test "given a dataset with no id, it returns an error" do
      dataset =
        Helper.sample_model()
        |> Map.delete(:id)

      assert {:error, _reason} = DatasetSearchIndex.update(dataset)
    end

    test "given a missing dataset index, it returns an error", %{es_indices: %{datasets: %{name: datasets}}} do
      delete_es_index(datasets)

      dataset = Helper.sample_model()

      assert {:error, _reason} = DatasetSearchIndex.update(dataset)
    end

    test "given an error from ES, it returns the error", %{es_indices: %{datasets: %{name: datasets}}} do
      dataset = Helper.sample_model()

      bypass = Bypass.open()
      reconfigure_es_url("http://localhost:#{bypass.port}")

      Bypass.stub(bypass, "HEAD", "/#{datasets}", fn conn ->
        Plug.Conn.resp(conn, 200, "")
      end)

      stub_path = "/#{datasets}/_doc/#{dataset.id}/_update"

      Bypass.stub(bypass, "POST", stub_path, fn conn ->
        Plug.Conn.resp(conn, 400, ~s({"error": "something bad happened"}))
      end)

      assert {:error, _reason} = DatasetSearchIndex.update(dataset)
    end
  end

  describe "replace/1" do
    test "given a new dataset, it creates it in elasticsearch" do
      dataset = Helper.sample_model()
      atomized_dataset = expected_dataset(dataset)

      assert {:ok, _} = DatasetSearchIndex.replace(dataset)
      assert {:ok, saved} = DatasetSearchIndex.get(dataset.id)
      assert atomized_dataset == saved
    end

    test "given an existing dataset, it merges the changes in elasticsearch" do
      existing_dataset = Helper.sample_model()
      assert {:ok, _saved} = DatasetSearchIndex.replace(existing_dataset)

      existing_id = existing_dataset.id
      updated_name = "Look at me, I'm a new name!"
      partial_update = %Model{id: existing_id, name: updated_name}

      assert {:ok, _} = DatasetSearchIndex.replace(partial_update)
      assert {:ok, replaced} = DatasetSearchIndex.get(partial_update.id)

      assert %Model{id: existing_id, name: updated_name} == replaced
    end

    test "the dataset it replaces is immediately searchable (refresh = true)" do
      dataset = Helper.sample_model()
      atomized_dataset = expected_dataset(dataset)

      assert {:ok, _saved} = DatasetSearchIndex.replace(dataset)

      assert {:ok, [atomized_dataset]} == DatasetSearchIndex.get_all()
    end

    test "given a dataset with no id, it returns an error" do
      dataset =
        Helper.sample_model()
        |> Map.delete(:id)

      assert {:error, _reason} = DatasetSearchIndex.replace(dataset)
    end

    test "given a missing dataset index, it returns an error", %{es_indices: %{datasets: %{name: datasets}}} do
      delete_es_index(datasets)

      dataset = Helper.sample_model()

      assert {:error, _reason} = DatasetSearchIndex.replace(dataset)
    end

    test "given an error returned from ES, it returns an error", %{es_indices: %{datasets: %{name: datasets}}} do
      dataset = Helper.sample_model()

      bypass = Bypass.open()
      reconfigure_es_url("http://localhost:#{bypass.port}")

      Bypass.stub(bypass, "HEAD", "/#{datasets}", fn conn ->
        Plug.Conn.resp(conn, 200, "")
      end)

      stub_path = "/#{datasets}/_doc/#{dataset.id}/"

      Bypass.stub(bypass, "PUT", stub_path, fn conn ->
        Plug.Conn.resp(conn, 400, ~s({"error": "something bad happened"}))
      end)

      assert {:error, _reason} = DatasetSearchIndex.replace(dataset)
    end
  end

  describe "replace_all/1" do
    test "given non-existing datasets index, it puts all datasets in the index", %{es_indices: %{datasets: %{name: datasets}}} do
      delete_es_index(datasets)

      dataset_one = Helper.sample_model()
      dataset_two = Helper.sample_model()
      datasets = [dataset_one, dataset_two]

      atomized_dataset_one = expected_dataset(dataset_one)
      atomized_dataset_two = expected_dataset(dataset_two)
      atomized_datasets = [atomized_dataset_one, atomized_dataset_two]

      assert {:ok, _} = DatasetSearchIndex.replace_all(datasets)
      assert {:ok, saved} = DatasetSearchIndex.get_all()
      assert atomized_datasets == saved
    end

    test "given an existing index, it puts all datasets in the index, destroying anything that was there already" do
      existing_dataset = Helper.sample_model()
      assert {:ok, _updated} = DatasetSearchIndex.update(existing_dataset)

      dataset_one = Helper.sample_model()
      dataset_two = Helper.sample_model()
      datasets = [dataset_one, dataset_two]

      atomized_dataset_one = expected_dataset(dataset_one)
      atomized_dataset_two = expected_dataset(dataset_two)
      atomized_datasets = [atomized_dataset_one, atomized_dataset_two]

      assert {:ok, _} = DatasetSearchIndex.replace_all(datasets)
      assert {:ok, saved} = DatasetSearchIndex.get_all()
      assert atomized_datasets == saved
    end

    test "if it fails to delete the index before replacing, it returns an error", %{es_indices: %{datasets: %{name: datasets}}} do
      bypass = Bypass.open()
      reconfigure_es_url("http://localhost:#{bypass.port}")

      Bypass.stub(bypass, "DELETE", "/#{datasets}", fn conn ->
        Plug.Conn.resp(conn, 500, ~s({"error": "something bad happened"}))
      end)

      datasets = [Helper.sample_model(), Helper.sample_model()]
      assert {:error, _} = DatasetSearchIndex.replace_all(datasets)
    end

    test "if it fails to create the index before replacing, it returns an error", %{es_indices: %{datasets: %{name: datasets}}} do
      bypass = Bypass.open()
      reconfigure_es_url("http://localhost:#{bypass.port}")

      Bypass.stub(bypass, "DELETE", "/#{datasets}", fn conn ->
        Plug.Conn.resp(conn, 200, "")
      end)

      Bypass.stub(bypass, "PUT", "/#{datasets}", fn conn ->
        Plug.Conn.resp(conn, 500, ~s({"error": "something even worse happened"}))
      end)

      datasets = [Helper.sample_model(), Helper.sample_model()]
      assert {:error, _} = DatasetSearchIndex.replace_all(datasets)
    end

    test "if it fails while bulk putting the datasets, it retuns an error", %{es_indices: %{datasets: %{name: datasets}}} do
      bypass = Bypass.open()
      reconfigure_es_url("http://localhost:#{bypass.port}")

      Bypass.stub(bypass, "DELETE", "/#{datasets}", fn conn ->
        Plug.Conn.resp(conn, 200, "")
      end)

      Bypass.stub(bypass, "PUT", "/#{datasets}", fn conn ->
        Plug.Conn.resp(conn, 200, ~s({"good": "things"}))
      end)

      Bypass.stub(bypass, "GET", "/#{datasets}", fn conn ->
        Plug.Conn.resp(conn, 200, ~s({"good": "things"}))
      end)

      Bypass.stub(bypass, "PUT", "/_bulk", fn conn ->
        Plug.Conn.resp(conn, 500, ~s({"error": "YOU. LOSE."}))
      end)

      datasets = [Helper.sample_model(), Helper.sample_model()]
      assert {:error, _} = DatasetSearchIndex.replace_all(datasets)
    end
  end

  defp reconfigure_es_url(url) do
    original_config = Application.get_env(:discovery_api, :elasticsearch)
    updated_config = Keyword.put(original_config, :url, url)

    Application.put_env(:discovery_api, :elasticsearch, updated_config)

    on_exit(fn ->
      Application.put_env(:discovery_api, :elasticsearch, original_config)
    end)
  end

  defp expected_dataset(dataset) do
    map =
      dataset
      |> Map.from_struct()
      |> AtomicMap.convert(safe: false, underscore: false)

    struct(Model, map)
  end
end
