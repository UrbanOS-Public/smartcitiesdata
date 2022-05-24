defmodule Andi.InputSchemas.InputConverterTest do
  use ExUnit.Case

  alias Ecto.Changeset
  alias Andi.InputSchemas.InputConverter
  alias SmartCity.TestDataGenerator
  alias Andi.InputSchemas.Datasets
  alias Andi.InputSchemas.Datasets.Dataset
  alias SmartCity.TestDataGenerator, as: TDG

  use Placebo

  describe "main conversions" do
    setup do
      allow(Datasets.is_unique?(any(), any(), any()), return: true)

      :ok
    end

    test "SmartCity.Dataset => Changeset => SmartCity.Dataset" do
      dataset =
        TestDataGenerator.create_dataset(%{
          business: %{issuedDate: "2020-01-03T00:00:00Z", modifiedDate: "2020-01-05T00:00:00Z"},
          technical: %{extractSteps: []}
        })

      {:ok, new_dataset} =
        dataset
        |> InputConverter.smrt_dataset_to_full_changeset()
        |> Ecto.Changeset.apply_changes()
        |> InputConverter.andi_dataset_to_smrt_dataset()

      assert new_dataset == dataset
    end

    test "SmartCity.Dataset => Changeset => SmartCity.Dataset with params" do
      dataset =
        TestDataGenerator.create_dataset(%{
          business: %{issuedDate: "2020-01-03T00:00:00Z", modifiedDate: "2020-01-05T00:00:00Z"},
          technical: %{
            sourceQueryParams: %{"foo" => "bar", "baz" => "biz"},
            sourceHeaders: %{"food" => "bard", "bad" => "bid"},
            schema: [
              %{
                name: "timstamp_field",
                type: "timestamp",
                format: "{YYYY}",
                default: %{provider: "timestamp", version: "2", opts: %{format: "{YYYY}", offset_in_seconds: -1000}}
              }
            ],
            extractSteps: [
              %{
                type: "http",
                context: %{
                  headers: %{"key" => "value"},
                  queryParams: %{"key" => "val"},
                  action: "POST",
                  body: %{
                    "url" => "http://www.something.com/",
                    "action" => "Add",
                    "params" => %{
                      "intA" => 3,
                      "intB" => 6
                    }
                  },
                  protocol: ["http1"],
                  url: "example.com"
                },
                assigns: %{}
              },
              %{
                type: "s3",
                context: %{
                  headers: %{"key2" => "val2"},
                  url: "blah.com"
                },
                assigns: %{}
              }
            ]
          }
        })

      {:ok, new_dataset} =
        dataset
        |> InputConverter.smrt_dataset_to_full_changeset()
        |> Ecto.Changeset.apply_changes()
        |> InputConverter.andi_dataset_to_smrt_dataset()

      assert new_dataset == dataset
    end

    test "conversion preserves empty string modified date" do
      dataset =
        TestDataGenerator.create_dataset(%{
          business: %{issuedDate: "2020-01-03T00:00:00Z", modifiedDate: ""},
          technical: %{extractSteps: []}
        })

      {:ok, new_dataset} =
        dataset
        |> InputConverter.smrt_dataset_to_full_changeset()
        |> Ecto.Changeset.apply_changes()
        |> InputConverter.andi_dataset_to_smrt_dataset()

      assert new_dataset == dataset
    end

    test "removes query params from sourceUrl on andi_dataset_to_smrt_dataset" do
      dataset =
        TestDataGenerator.create_dataset(%{
          technical: %{
            sourceUrl: "http://example.com",
            sourceQueryParams: %{}
          }
        })
        |> InputConverter.smrt_dataset_to_full_changeset()
        |> Ecto.Changeset.apply_changes()

      {:ok, smrt_dataset} =
        dataset
        |> InputConverter.form_data_to_full_changeset(%{
          "technical" => %{
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
          }
        })
        |> Changeset.apply_changes()
        |> InputConverter.andi_dataset_to_smrt_dataset()

      assert %SmartCity.Dataset{
               technical: %{
                 sourceUrl: "http://example.com",
                 sourceQueryParams: %{
                   "key" => "value",
                   "key1" => "value1"
                 }
               }
             } = smrt_dataset
    end

    test "removes query params from extract step url on andi_dataset_to_smrt_dataset" do
      dataset =
        TestDataGenerator.create_dataset(%{
          technical: %{
            extractSteps: [
              %{
                type: "http",
                context: %{
                  action: "GET",
                  url: "example.com?whats=up"
                }
              }
            ]
          }
        })
        |> InputConverter.smrt_dataset_to_full_changeset()
        |> Ecto.Changeset.apply_changes()

      {:ok, smrt_dataset} =
        dataset
        |> InputConverter.form_data_to_full_changeset(%{
          "technical" => %{
            "extractSteps" => [
              %{
                "type" => "http",
                "context" => %{
                  "url" => "http://example.com?key=value&key1=value1",
                  "queryParams" => [
                    %{
                      "key" => "key",
                      "value" => "value"
                    },
                    %{
                      "key" => "key1",
                      "value" => "value1"
                    }
                  ]
                }
              }
            ]
          }
        })
        |> Changeset.apply_changes()
        |> InputConverter.andi_dataset_to_smrt_dataset()

      assert %SmartCity.Dataset{
               technical: %{
                 extractSteps: [
                   %{
                     type: "http",
                     context: %{
                       url: "http://example.com",
                       queryParams: %{
                         "key" => "value",
                         "key1" => "value1"
                       }
                     }
                   }
                 ]
               }
             } = smrt_dataset
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
        |> InputConverter.smrt_dataset_to_full_changeset()
        |> Ecto.Changeset.apply_changes()

      assert %{
               technical: %{
                 sourceUrl: "http://example.com?dog=cat&squashed=bro&wont=get",
                 sourceQueryParams: [
                   %{key: "dog", value: "cat"},
                   %{key: "squashed", value: "bro"},
                   %{key: "wont", value: "get"}
                 ]
               }
             } = dataset
    end

    test "excluding the schema from the changes you want to overlay on the dataset does not blow up" do
      dataset =
        TestDataGenerator.create_dataset(%{
          technical: %{
            schema: [
              %{
                name: "hello",
                type: "string"
              },
              %{
                name: "world",
                type: "map",
                subSchema: [
                  %{
                    name: "goodbye",
                    type: "list",
                    itemType: "string"
                  },
                  %{
                    name: "richard",
                    type: "float"
                  }
                ]
              }
            ]
          }
        })
        |> InputConverter.smrt_dataset_to_full_changeset()
        |> Ecto.Changeset.apply_changes()

      dataset_input =
        InputConverter.form_data_to_full_changeset(dataset, %{})
        |> Ecto.Changeset.apply_changes()

      assert %{
               technical: %{
                 schema: [
                   %{
                     name: "hello",
                     type: "string"
                   },
                   %{
                     name: "world",
                     type: "map",
                     subSchema: [
                       %{
                         name: "goodbye",
                         type: "list"
                       },
                       %{
                         name: "richard",
                         type: "float"
                       }
                     ]
                   }
                 ]
               }
             } = dataset_input
    end
  end

  describe "smrt_dataset_to_full_changeset/?" do
    test "given schema that has a nested list field, it attaches bread crumbs to it" do
      schema_parent_field_id = UUID.uuid4()
      schema_child_field_id = UUID.uuid4()

      dataset =
        TDG.create_dataset(%{
          technical: %{
            schema: [
              %{
                name: "list_field_parent",
                id: schema_parent_field_id,
                type: "list",
                subSchema: [
                  %{name: "list_field_child_one", id: schema_child_field_id, type: "list"},
                  %{name: "list_field_child_two", id: UUID.uuid4(), type: "string"}
                ]
              }
            ]
          }
        })

      dataset_id = dataset.id
      changeset = InputConverter.smrt_dataset_to_changeset(dataset)

      schema =
        Ecto.Changeset.apply_changes(changeset)
        |> get_in([:technical, :schema])

      assert [
               %{
                 id: ^schema_parent_field_id,
                 dataset_id: ^dataset_id,
                 bread_crumb: "list_field_parent",
                 subSchema: [
                   %{
                     id: ^schema_child_field_id,
                     dataset_id: ^dataset_id,
                     bread_crumb: "list_field_parent > list_field_child_one"
                   },
                   %{
                     dataset_id: ^dataset_id,
                     bread_crumb: "list_field_parent > list_field_child_two"
                   }
                 ]
               }
             ] = schema
    end
  end

  @valid_form_data %{
    "id" => "id",
    "business" => %{
      "benefitRating" => 0,
      "riskRating" => 1,
      "contactEmail" => "contact@email.com",
      "contactName" => "contactName",
      "dataTitle" => "dataTitle",
      "orgTitle" => "orgTitle",
      "description" => "description",
      "issuedDate" => "2020-01-01T00:00:00Z",
      "license" => "https://www.test.net",
      "publishFrequency" => "publishFrequency"
    },
    "technical" => %{
      "cadence" => "never",
      "dataName" => "dataName",
      "orgName" => "orgName",
      "private" => false,
      "schema" => %{
        "0" => %{"id" => Ecto.UUID.generate(), "name" => "name", "type" => "type", "dataset_id" => "id", "bread_crumb" => "name"}
      },
      "sourceFormat" => "sourceFormat",
      "sourceHeaders" => %{
        "0" => %{"id" => Ecto.UUID.generate(), "key" => "foo", "value" => "bar"},
        "1" => %{"id" => Ecto.UUID.generate(), "key" => "fizzle", "value" => "bizzle"}
      },
      "sourceQueryParams" => %{
        "0" => %{"id" => Ecto.UUID.generate(), "key" => "chain", "value" => "city"},
        "1" => %{"id" => Ecto.UUID.generate(), "key" => "F# minor", "value" => "add"}
      },
      "sourceType" => "remote",
      "sourceUrl" => "https://sourceurl.com?chain=city&F%23+minor=add"
    }
  }

  describe "form_data_to_ui_changeset/1" do
    setup do
      allow(Datasets.is_unique?(any(), any(), any()), return: false)

      :ok
    end

    test "given empty form data it returns a diff that includes whole dataset" do
      changeset = InputConverter.form_data_to_ui_changeset(%{})

      refute changeset.valid?
      assert changeset.action == nil
    end

    test "given partial form data it returns a diff that includes whole dataset" do
      form_data = %{
        "technical" => %{
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
        }
      }

      changeset = InputConverter.form_data_to_ui_changeset(form_data)

      refute changeset.valid?
      assert changeset.action == nil

      assert %{
               technical: %{
                 sourceUrl: "http://example.com?key=value&key1=value1",
                 sourceQueryParams: [
                   %{key: "key", value: "value"},
                   %{key: "key1", value: "value1"}
                 ]
               }
             } = Ecto.Changeset.apply_changes(changeset)
    end

    test "given a full and valid piece of form data it returns a diff that includes whole dataset" do
      changeset = InputConverter.form_data_to_ui_changeset(@valid_form_data)

      assert changeset.valid?
      assert changeset.action == nil

      valid_id = @valid_form_data["id"]

      assert %{id: ^valid_id} = Ecto.Changeset.apply_changes(changeset)
    end
  end

  describe "form_data_to_full_ui_changeset/1" do
    setup do
      allow(Datasets.is_unique?(any(), any(), any()), return: false)

      :ok
    end

    test "given otherwise valid form data, it applies full validation (unique check)" do
      changeset = InputConverter.form_data_to_full_ui_changeset(@valid_form_data)

      refute changeset.valid?
      assert changeset.action == nil

      valid_id = @valid_form_data["id"]

      assert %{id: ^valid_id} = Ecto.Changeset.apply_changes(changeset)
    end
  end

  describe "form_data_to_full_changeset/2" do
    setup do
      allow(Datasets.is_unique?(any(), any(), any()), return: true)

      :ok
    end

    test "given empty form data it returns a diff that includes whole dataset" do
      changeset = InputConverter.form_data_to_full_changeset(%Dataset{}, %{})

      refute changeset.valid?
    end

    test "given partial form data it returns a diff that includes whole dataset" do
      form_data = %{
        "technical" => %{
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
        }
      }

      changeset = InputConverter.form_data_to_full_changeset(%Dataset{id: "existing id?"}, form_data)

      refute changeset.valid?

      assert %{
               id: "existing id?",
               technical: %{
                 sourceUrl: "http://example.com?key=value&key1=value1",
                 sourceQueryParams: [
                   %{key: "key", value: "value"},
                   %{key: "key1", value: "value1"}
                 ]
               }
             } = Ecto.Changeset.apply_changes(changeset)
    end

    test "given a full and valid piece of form data it returns a diff that includes whole dataset" do
      changeset = InputConverter.form_data_to_full_changeset(%Dataset{id: "overwritten?"}, @valid_form_data)

      assert changeset.valid?

      valid_id = @valid_form_data["id"]

      assert %{id: ^valid_id} = Ecto.Changeset.apply_changes(changeset)
    end
  end

  describe "keywords_to_list" do
    test "turns nil into empty array" do
      assert [] = InputConverter.keywords_to_list(nil)
    end

    test "turns empty string into empty array" do
      assert [] = InputConverter.keywords_to_list("")
    end

    test "returns list unchanged" do
      keywords = ["one", "blue", "sky"]
      assert keywords = InputConverter.keywords_to_list(keywords)
    end

    test "comma space separated string turns into array of strings" do
      keywords = "one, blue, sky"
      assert ["one", "blue", "sky"] = InputConverter.keywords_to_list(keywords)
    end

    test "comma separated string with no spaces turns into array of strings" do
      keywords = "one,blue,sky"
      assert ["one", "blue", "sky"] = InputConverter.keywords_to_list(keywords)
    end

    test "internal spaces are preserved within a keyword" do
      keywords = "example, one blue sky"
      assert = ["example", "one blue sky"] = InputConverter.keywords_to_list(keywords)
    end

    test "leading and trailing spaces are trimmed from a keyword" do
      keywords = "  one,  blue  , sky  "
      assert ["one", "blue", "sky"] = InputConverter.keywords_to_list(keywords)
    end
  end
end
