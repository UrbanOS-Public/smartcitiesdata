defmodule Andi.InputSchemas.InputConverterTest do
  use ExUnit.Case

  alias Ecto.Changeset
  alias Andi.InputSchemas.InputConverter
  alias SmartCity.TestDataGenerator

  test "SmartCity.Dataset => Changeset => SmartCity.Dataset" do
    dataset =
      TestDataGenerator.create_dataset(%{
        business: %{issuedDate: "2020-01-03 00:00:00Z", modifiedDate: "2020-01-05 00:00:00Z"}
      })

    new_dataset =
      dataset
      |> InputConverter.changeset_from_dataset()
      |> Changeset.apply_changes()
      |> InputConverter.restruct(dataset)

    assert new_dataset == dataset
  end

  test "SmartCity.Dataset => Changeset => SmartCity.Dataset with source params" do
    dataset =
      TestDataGenerator.create_dataset(%{
        business: %{issuedDate: "2020-01-03 00:00:00Z", modifiedDate: "2020-01-05 00:00:00Z"},
        technical: %{
          sourceQueryParams: %{"foo" => "bar", "baz" => "biz"},
          sourceHeaders: %{"food" => "bard", "bad" => "bid"}
        }
      })

    new_dataset =
      dataset
      |> InputConverter.changeset_from_dataset()
      |> Changeset.apply_changes()
      |> InputConverter.restruct(dataset)

    assert new_dataset == dataset
  end

  test "conversion preserves empty string modified date" do
    dataset =
      TestDataGenerator.create_dataset(%{
        business: %{issuedDate: "2020-01-03 00:00:00Z", modifiedDate: ""}
      })

    new_dataset =
      dataset
      |> InputConverter.changeset_from_dataset()
      |> Changeset.apply_changes()
      |> InputConverter.restruct(dataset)

    assert new_dataset == dataset
  end

  test "removes query params from sourceUrl on restruct" do
    dataset =
      TestDataGenerator.create_dataset(%{
        technical: %{
          sourceUrl: "http://example.com",
          sourceQueryParams: %{}
        }
      })

      dataset =
        dataset
        |> InputConverter.changeset_from_dataset(%{
          "sourceUrl" => "http://example.com?key=value&key1=value1",
          "sourceQueryParams" => %{
            "0" => %{
              "key" => "key",
              "value" => "value"
            },
            "1" => %{
              "key" => "key1",
              "value" => "value1"
            }
          }
        })
        |> Changeset.apply_changes()
        |> InputConverter.restruct(dataset)

      assert %SmartCity.Dataset{
        technical: %{
          sourceUrl: "http://example.com",
          sourceQueryParams: %{
            "key" => "value", "key1" => "value1"
          }
        }
      } = dataset
  end

  test "converting a dataset to a changeset syncs source url and query params" do
    dataset =
      TestDataGenerator.create_dataset(%{
        technical: %{
          sourceUrl: "http://example.com?dog=cat&wont=get",
          sourceQueryParams: %{
            "wont" => "get",
            "squashed" => "bro"
          }
        }
      })

    dataset_input = InputConverter.changeset_from_dataset(dataset)
    |> Ecto.Changeset.apply_changes()

    assert %{
      sourceUrl: "http://example.com?dog=cat&squashed=bro&wont=get",
      sourceQueryParams: [
        %{key: "dog", value: "cat"},
        %{key: "squashed", value: "bro"},
        %{key: "wont", value: "get"}
      ]
    } = dataset_input
  end
end
