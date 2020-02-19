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

  test "conversion strips query string hardcoded on base source URL" do
    dataset =
      TestDataGenerator.create_dataset(%{technical: %{sourceUrl: "test.com?a=b&b=c"}})

    new_dataset =
      dataset
      |> InputConverter.changeset_from_dataset()
      |> Changeset.apply_changes()
      |> InputConverter.restruct(dataset)

    assert "test.com" == new_dataset.technical.sourceUrl
  end
end
