defmodule Andi.Event.EventHandlerTest do
  use ExUnit.Case
  use Andi.DataCase
  use Properties, otp_app: :andi

  import SmartCity.TestHelper
  import SmartCity.Event
  import Mock
  
  alias SmartCity.UserOrganizationAssociate
  alias SmartCity.UserOrganizationDisassociate
  alias Andi.Schemas.User
  alias SmartCity.TestDataGenerator, as: TDG
  alias Andi.InputSchemas.Organization
  alias Andi.InputSchemas.Organizations
  alias Andi.InputSchemas.Datasets
  alias Andi.DatasetCache
  alias DeadLetter
  alias Andi.InputSchemas.Ingestions
  alias Andi.Services.IngestionStore
  alias Andi.Services.DatasetStore
  alias Andi.Services.OrgStore
  alias Andi.Harvest.Harvester

  @moduletag shared_data_connection: true
  @instance_name Andi.instance_name()
  getter(:kafka_broker, generic: true)

  describe "Dataset Update" do
    test "A failing message gets placed on dead letter queue and discarded" do
      id_for_invalid_dataset = UUID.uuid4()
      invalid_dataset = TDG.create_dataset(%{id: id_for_invalid_dataset})

      with_mock(DatasetCache, [add_dataset_info: fn(_) -> raise "nope" end]) do
        id = UUID.uuid4()
        valid_dataset = TDG.create_dataset(%{id: id})

        Brook.Event.send(@instance_name, dataset_update(), __MODULE__, invalid_dataset)
        Brook.Event.send(@instance_name, dataset_update(), __MODULE__, valid_dataset)

        eventually(fn ->
          valid_dataset_from_ecto = Datasets.get(id)
          assert valid_dataset_from_ecto != nil
          assert valid_dataset_from_ecto.id == valid_dataset.id

          invalid_dataset_from_ecto = Datasets.get(id_for_invalid_dataset)
          assert invalid_dataset_from_ecto == nil

          failed_messages =
            Elsa.Fetch.fetch(kafka_broker(), "dead-letters")
            |> elem(2)
            |> Enum.filter(fn message ->
              actual = Jason.decode!(message.value)

              case actual["dataset_ids"] do
                nil -> false
                dataset_ids -> id_for_invalid_dataset in dataset_ids
              end
            end)

          assert 1 == length(failed_messages)
        end)
      end
    end
  end

  describe "Ingestion Update" do
    test "A failing message gets placed on dead letter queue and discarded" do
      dataset_id = UUID.uuid4()
      dataset = TDG.create_dataset(%{id: dataset_id})

      Brook.Event.send(@instance_name, dataset_update(), __MODULE__, dataset)

      id_for_invalid_ingestion = UUID.uuid4()
      invalid_ingestion = TDG.create_ingestion(%{id: id_for_invalid_ingestion})

      with_mock(IngestionStore, [update: fn(invalid_ingestion) -> raise "nope" end]) do
        id = UUID.uuid4()
        valid_ingestion = TDG.create_ingestion(%{id: id, targetDatasets: [dataset.id]})

        Brook.Event.send(@instance_name, ingestion_update(), __MODULE__, invalid_ingestion)
        Brook.Event.send(@instance_name, ingestion_update(), __MODULE__, valid_ingestion)

        eventually(fn ->
          valid_ingestion_from_ecto = Ingestions.get(id)
          assert valid_ingestion_from_ecto != nil
          assert valid_ingestion_from_ecto.id == valid_ingestion.id

          invalid_ingestion_from_ecto = Ingestions.get(id_for_invalid_ingestion)
          assert invalid_ingestion_from_ecto == nil

          failed_messages =
            Elsa.Fetch.fetch(kafka_broker(), "dead-letters")
            |> elem(2)
            |> Enum.filter(fn message ->
              actual = Jason.decode!(message.value)
              actual["ingestion_id"] == id_for_invalid_ingestion
            end)

          assert 1 == length(failed_messages)
        end)
      end
    end
  end

  describe "Ingestion Delete" do
    test "A failing message gets placed on dead letter queue and discarded" do
      dataset_id = UUID.uuid4()
      dataset = TDG.create_dataset(%{id: dataset_id})

      id_for_invalid_ingestion = UUID.uuid4()
      invalid_ingestion = TDG.create_ingestion(%{id: id_for_invalid_ingestion})

      with_mock(IngestionStore, [delete: fn(id_for_invalid_ingestion) -> raise "nope" end]) do
        Brook.Event.send(@instance_name, ingestion_delete(), __MODULE__, invalid_ingestion)
        Brook.Event.send(@instance_name, dataset_update(), __MODULE__, dataset)

        eventually(fn ->
          valid_dataset_from_ecto = Datasets.get(dataset_id)
          assert valid_dataset_from_ecto != nil
          assert valid_dataset_from_ecto.id == dataset.id

          failed_messages =
            Elsa.Fetch.fetch(kafka_broker(), "dead-letters")
            |> elem(2)
            |> Enum.filter(fn message ->
              actual = Jason.decode!(message.value)
              actual["ingestion_id"] == id_for_invalid_ingestion
            end)

          assert 1 == length(failed_messages)
        end)
      end
    end
  end

  describe "Org Update" do
    test "A failing message gets placed on dead letter queue and discarded" do
      dataset_id = UUID.uuid4()
      dataset = TDG.create_dataset(%{id: dataset_id})

      id_for_org = UUID.uuid4()
      invalid_org = TDG.create_organization(%{id: id_for_org})

      with_mock(OrgStore, [update: fn(invalid_org) -> raise "nope" end]) do
        Brook.Event.send(@instance_name, organization_update(), __MODULE__, invalid_org)
        Brook.Event.send(@instance_name, dataset_update(), __MODULE__, dataset)

        eventually(fn ->
          valid_dataset_from_ecto = Datasets.get(dataset_id)
          assert valid_dataset_from_ecto != nil
          assert valid_dataset_from_ecto.id == dataset.id

          failed_messages =
            Elsa.Fetch.fetch(kafka_broker(), "dead-letters")
            |> elem(2)
            |> Enum.filter(fn message ->
              actual = Jason.decode!(message.value)

              case actual["original_message"] do
                %{"id" => message_org_id} ->
                  message_org_id == id_for_org

                _ ->
                  false
              end
            end)

          assert 1 == length(failed_messages)
        end)
      end
    end
  end

  describe "#{user_organization_associate()}" do
    setup do
      org = TDG.create_organization(%{})

      org
      |> Organization.changeset()
      |> Organizations.save()

      %{org_id: org.id}
    end

    @tag capture_log: true
    test "org is associated to existing user", %{org_id: org_id} do
      old_user_subject_id = UUID.uuid4()

      {:ok, user} =
        User.create_or_update(old_user_subject_id, %{
          subject_id: old_user_subject_id,
          email: "blah@blah.com",
          name: "Mr. Blah"
        })

      assert User.get_by_subject_id(old_user_subject_id) != nil

      association = %UserOrganizationAssociate{org_id: org_id, subject_id: old_user_subject_id, email: "blah@blah.com"}
      Brook.Event.send(@instance_name, user_organization_associate(), __MODULE__, association)

      eventually(fn ->
        user_from_ecto = User.get_by_subject_id(old_user_subject_id)
        assert user_from_ecto.id == user.id
        assert user_from_ecto.organizations |> Enum.map(fn org -> org.id end) |> Enum.any?(fn id -> id == org_id end)
      end)
    end

    @tag capture_log: true
    test "org can be associated to multiple existing users", %{org_id: org_id} do
      subject1 = "auth1"
      subject2 = "auth2"

      {:ok, user1} =
        User.create_or_update(subject1, %{
          subject_id: subject1,
          email: "blah@blah.com",
          name: "Blah"
        })

      {:ok, user2} =
        User.create_or_update(subject2, %{
          subject_id: subject2,
          email: "blah2@blah.com",
          name: "Blah"
        })

      assert User.get_by_subject_id(subject1) != nil

      association = %UserOrganizationAssociate{org_id: org_id, subject_id: subject1, email: "blah@blah.com"}
      Brook.Event.send(@instance_name, user_organization_associate(), __MODULE__, association)

      association = %UserOrganizationAssociate{org_id: org_id, subject_id: subject2, email: "blah2@blah.com"}
      Brook.Event.send(@instance_name, user_organization_associate(), __MODULE__, association)

      eventually(fn ->
        user_from_ecto = User.get_by_subject_id(subject1)
        assert user_from_ecto.id == user1.id
        assert user_from_ecto.organizations |> Enum.map(fn org -> org.id end) |> Enum.any?(fn id -> id == org_id end)
      end)

      eventually(fn ->
        user_from_ecto = User.get_by_subject_id(subject2)
        assert user_from_ecto.id == user2.id
        assert user_from_ecto.organizations |> Enum.map(fn org -> org.id end) |> Enum.any?(fn id -> id == org_id end)
      end)
    end

    test "A failing message gets placed on dead letter queue and discarded" do
      dataset_id = UUID.uuid4()
      dataset = TDG.create_dataset(%{id: dataset_id})

      subject_id = UUID.uuid4()
      org_id = UUID.uuid4()
      invalid_org = TDG.create_organization(%{id: org_id})

      with_mock(User, [associate_with_organization: fn(_, _) -> raise "nope" end]) do
        association = %UserOrganizationAssociate{org_id: org_id, subject_id: subject_id, email: "blah@blah.com"}

        Brook.Event.send(@instance_name, user_organization_associate(), __MODULE__, association)
        Brook.Event.send(@instance_name, dataset_update(), __MODULE__, dataset)

        eventually(fn ->
          valid_dataset_from_ecto = Datasets.get(dataset_id)
          assert valid_dataset_from_ecto != nil
          assert valid_dataset_from_ecto.id == dataset.id

          failed_messages =
            Elsa.Fetch.fetch(kafka_broker(), "dead-letters")
            |> elem(2)
            |> Enum.filter(fn message ->
              actual = Jason.decode!(message.value)

              case actual["original_message"] do
                %{"org_id" => message_org_id, "subject_id" => message_subject_id} ->
                  message_org_id == org_id && message_subject_id == subject_id

                _ ->
                  false
              end
            end)

          assert 1 == length(failed_messages)
        end)
      end
    end
  end

  describe "User org disassociate" do
    test "A failing message gets placed on dead letter queue and discarded" do
      dataset_id = UUID.uuid4()
      dataset = TDG.create_dataset(%{id: dataset_id})

      subject_id = UUID.uuid4()
      org_id = UUID.uuid4()
      invalid_org = TDG.create_organization(%{id: org_id})

      with_mock(User, [disassociate_with_organization: fn(_, _) -> raise "nope" end]) do
        disassociation = %UserOrganizationDisassociate{org_id: org_id, subject_id: subject_id}

        Brook.Event.send(@instance_name, user_organization_disassociate(), __MODULE__, disassociation)
        Brook.Event.send(@instance_name, dataset_update(), __MODULE__, dataset)

        eventually(fn ->
          valid_dataset_from_ecto = Datasets.get(dataset_id)
          assert valid_dataset_from_ecto != nil
          assert valid_dataset_from_ecto.id == dataset.id

          failed_messages =
            Elsa.Fetch.fetch(kafka_broker(), "dead-letters")
            |> elem(2)
            |> Enum.filter(fn message ->
              actual = Jason.decode!(message.value)

              case actual["original_message"] do
                %{"org_id" => message_org_id, "subject_id" => message_subject_id} ->
                  message_org_id == org_id && message_subject_id == subject_id

                _ ->
                  false
              end
            end)

          assert 1 == length(failed_messages)
        end)
      end
    end
  end

  describe "Dataset Harvest Start" do
    test "A failing message gets placed on dead letter queue and discarded" do
      dataset_id = UUID.uuid4()
      dataset = TDG.create_dataset(%{id: dataset_id})

      org_id = UUID.uuid4()
      invalid_org = TDG.create_organization(%{id: org_id})

      with_mock(TelemetryEvent, [add_event_metrics: fn([app: "andi", author: _, dataset_id: _, event_type: dataset_harvest_start()], [:events_handled]) -> raise "nope" end]) do
        Brook.Event.send(@instance_name, dataset_harvest_start(), __MODULE__, invalid_org)
        Brook.Event.send(@instance_name, dataset_update(), __MODULE__, dataset)

        eventually(fn ->
          valid_dataset_from_ecto = Datasets.get(dataset_id)
          assert valid_dataset_from_ecto != nil
          assert valid_dataset_from_ecto.id == dataset.id

          failed_messages =
            Elsa.Fetch.fetch(kafka_broker(), "dead-letters")
            |> elem(2)
            |> Enum.filter(fn message ->
              actual = Jason.decode!(message.value)

              case actual["original_message"] do
                %{"id" => message_org_id} ->
                  message_org_id == org_id

                _ ->
                  false
              end
            end)

          assert 1 == length(failed_messages)
        end)
      end
    end
  end

  describe "Dataset Harvest End" do
    test "A failing message gets placed on dead letter queue and discarded" do
      dataset_id = UUID.uuid4()
      dataset = TDG.create_dataset(%{id: dataset_id})

      fake_id = UUID.uuid4()
      fake_harvested_dataset = %{fake: fake_id}

      with_mock(Organizations, [update_harvested_dataset: fn(_) -> raise "nope" end]) do
        Brook.Event.send(@instance_name, dataset_harvest_end(), __MODULE__, fake_harvested_dataset)
        Brook.Event.send(@instance_name, dataset_update(), __MODULE__, dataset)

        eventually(fn ->
          valid_dataset_from_ecto = Datasets.get(dataset_id)
          assert valid_dataset_from_ecto != nil
          assert valid_dataset_from_ecto.id == dataset.id

          failed_messages =
            Elsa.Fetch.fetch(kafka_broker(), "dead-letters")
            |> elem(2)
            |> Enum.filter(fn message ->
              actual = Jason.decode!(message.value)

              case actual["original_message"] do
                %{"fake" => message_fake_id} ->
                  message_fake_id == fake_id

                _ ->
                  false
              end
            end)

          assert 1 == length(failed_messages)
        end)
      end
    end
  end

  describe "Modified Date Migration Start" do
    test "A failing message gets placed on dead letter queue and discarded" do
      existing_messages =
        Elsa.Fetch.fetch(kafka_broker(), "dead-letters")
        |> elem(2)
        |> Enum.filter(fn message ->
          actual = Jason.decode!(message.value)

          case actual["original_message"] do
            %{"type" => message_type} ->
              message_type == "migration:modified_date:start"

            _ ->
              false
          end
        end)
        |> length

      dataset_id = UUID.uuid4()
      dataset = TDG.create_dataset(%{id: dataset_id})

      with_mock(Andi.Migration.ModifiedDateMigration, [do_migration: fn() -> raise "nope" end]) do
        Brook.Event.send(@instance_name, "migration:modified_date:start", __MODULE__, %{})
        Brook.Event.send(@instance_name, dataset_update(), __MODULE__, dataset)

        eventually(fn ->
          valid_dataset_from_ecto = Datasets.get(dataset_id)
          assert valid_dataset_from_ecto != nil
          assert valid_dataset_from_ecto.id == dataset.id

          failed_messages =
            Elsa.Fetch.fetch(kafka_broker(), "dead-letters")
            |> elem(2)
            |> Enum.filter(fn message ->
              actual = Jason.decode!(message.value)

              case actual["original_message"] do
                %{"type" => message_type} ->
                  message_type == "migration:modified_date:start"

                _ ->
                  false
              end
            end)

          assert length(failed_messages) == existing_messages + 1
        end)
      end
    end
  end

  describe "Data Ingest End" do
    test "A failing message gets placed on dead letter queue and discarded" do
      dataset_id = UUID.uuid4()
      dataset = TDG.create_dataset(%{id: dataset_id})

      with_mock(TelemetryEvent, [add_event_metrics: fn([app: _, author: _, dataset_id: _, event_type: data_ingest_end()], [:events_handled]) -> raise "nope" end]) do
        Brook.Event.send(@instance_name, data_ingest_end(), __MODULE__, dataset)
        Brook.Event.send(@instance_name, dataset_update(), __MODULE__, dataset)

        eventually(fn ->
          valid_dataset_from_ecto = Datasets.get(dataset_id)
          assert valid_dataset_from_ecto != nil
          assert valid_dataset_from_ecto.id == dataset.id

          failed_messages =
            Elsa.Fetch.fetch(kafka_broker(), "dead-letters")
            |> elem(2)
            |> Enum.filter(fn message ->
              actual = Jason.decode!(message.value)

              case actual["original_message"] do
                %{"id" => message_dataset_id} ->
                  message_dataset_id == dataset_id

                _ ->
                  false
              end
            end)

          assert length(failed_messages) == 1
        end)
      end
    end
  end

  describe "Dataset Delete" do
    test "A failing message gets placed on dead letter queue and discarded" do
      dataset_id = UUID.uuid4()
      dataset = TDG.create_dataset(%{id: dataset_id})

      with_mock(DatasetStore, [delete: fn(dataset_id) -> raise "nope" end]) do
        Brook.Event.send(@instance_name, dataset_delete(), __MODULE__, dataset)
        Brook.Event.send(@instance_name, dataset_update(), __MODULE__, dataset)

        eventually(fn ->
          valid_dataset_from_ecto = Datasets.get(dataset_id)
          assert valid_dataset_from_ecto != nil
          assert valid_dataset_from_ecto.id == dataset.id

          failed_messages =
            Elsa.Fetch.fetch(kafka_broker(), "dead-letters")
            |> elem(2)
            |> Enum.filter(fn message ->
              actual = Jason.decode!(message.value)

              case actual["original_message"] do
                %{"id" => message_dataset_id} ->
                  message_dataset_id == dataset_id

                _ ->
                  false
              end
            end)

          assert length(failed_messages) == 1
        end)
      end
    end
  end

  describe "#{user_login()}" do
    test "persists user if subject id does not match one in ecto" do
      new_user_subject_id = UUID.uuid4()

      {:ok, user} = %{subject_id: new_user_subject_id, email: "cam@cam.com", name: "CamCam"} |> SmartCity.User.new()

      assert nil == User.get_by_subject_id(user.subject_id)

      Brook.Event.send(@instance_name, user_login(), __MODULE__, user)

      eventually(
        fn ->
          user_from_ecto = User.get_by_subject_id(new_user_subject_id)
          assert user_from_ecto != nil
          assert user_from_ecto.subject_id == user.subject_id
          assert user_from_ecto.email == user.email
          assert user_from_ecto.name == user.name
        end,
        1_000,
        30
      )
    end

    test "does not persist user if subject_id already exists" do
      old_user_subject_id = UUID.uuid4()

      {:ok, user} =
        User.create_or_update(old_user_subject_id, %{
          subject_id: old_user_subject_id,
          email: "blah@blah.com",
          name: "Blah"
        })

      assert User.get_by_subject_id(old_user_subject_id) != nil

      new_user_same_subject_id = Map.put(user, :email, "cam@cam.com")
      Brook.Event.send(@instance_name, user_login(), __MODULE__, new_user_same_subject_id)

      user_from_ecto = User.get_by_subject_id(old_user_subject_id)
      assert user_from_ecto.id == user.id
    end

    test "A failing message gets placed on dead letter queue and discarded" do
      dataset_id = UUID.uuid4()
      dataset = TDG.create_dataset(%{id: dataset_id})

      subject_id = UUID.uuid4()
      {:ok, user} = %{subject_id: subject_id, email: "abc", name: "abc"} |> SmartCity.User.new()

      with_mock(User, [get_by_subject_id: fn(subject_id) -> raise "nope" end]) do
        Brook.Event.send(@instance_name, user_login(), __MODULE__, user)
        Brook.Event.send(@instance_name, dataset_update(), __MODULE__, dataset)

        eventually(fn ->
          valid_dataset_from_ecto = Datasets.get(dataset_id)
          assert valid_dataset_from_ecto != nil
          assert valid_dataset_from_ecto.id == dataset.id

          failed_messages =
            Elsa.Fetch.fetch(kafka_broker(), "dead-letters")
            |> elem(2)
            |> Enum.filter(fn message ->
              actual = Jason.decode!(message.value)

              case actual["original_message"] do
                %{"subject_id" => message_subject_id} ->
                  message_subject_id == subject_id

                _ ->
                  false
              end
            end)

          assert length(failed_messages) == 1
        end)
      end
    end
  end
end
