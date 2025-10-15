defmodule Andi.Event.EventHandlerTest do
  use ExUnit.Case
  use Andi.DataCase
  use Properties, otp_app: :andi

  import SmartCity.TestHelper
  import SmartCity.Event

  alias SmartCity.UserOrganizationAssociate
  alias SmartCity.UserOrganizationDisassociate
  alias Andi.Schemas.User
  alias SmartCity.TestDataGenerator, as: TDG
  alias Andi.InputSchemas.Organization
  alias Andi.InputSchemas.Organizations
  alias Andi.InputSchemas.Datasets
  alias Andi.InputSchemas.Ingestions
  alias Andi.InputSchemas.MessageErrors
  alias Andi.InputSchemas.EventLogs

  @moduletag shared_data_connection: true
  @instance_name Andi.instance_name()
  getter(:kafka_broker, generic: true)

  describe "Dataset Update - happy path" do
    test "successfully processes and persists dataset" do
      dataset_id = UUID.uuid4()
      dataset = TDG.create_dataset(%{id: dataset_id})

      Brook.Event.send(@instance_name, dataset_update(), __MODULE__, dataset)

      eventually(fn ->
        persisted_dataset = Datasets.get(dataset_id)
        assert persisted_dataset != nil
        assert persisted_dataset.id == dataset.id
      end)
    end

    test "updates ingested time for dataset" do
      before_time = DateTime.utc_now()
      dataset_id = UUID.uuid4()
      dataset = TDG.create_dataset(%{id: dataset_id})

      Brook.Event.send(@instance_name, dataset_update(), __MODULE__, dataset)

      eventually(fn ->
        persisted_dataset = Datasets.get(dataset_id)
        assert persisted_dataset != nil
        assert persisted_dataset.ingestedTime != nil
        assert DateTime.compare(persisted_dataset.ingestedTime, before_time) in [:gt, :eq]
      end)
    end
  end

  describe "Ingestion Update - happy path" do
    test "successfully processes and persists ingestion" do
      # First create a dataset that the ingestion references
      dataset_id = UUID.uuid4()
      dataset = TDG.create_dataset(%{id: dataset_id})
      Brook.Event.send(@instance_name, dataset_update(), __MODULE__, dataset)

      eventually(fn ->
        assert Datasets.get(dataset_id) != nil
      end)

      # Now create and test the ingestion
      ingestion_id = UUID.uuid4()
      ingestion = TDG.create_ingestion(%{id: ingestion_id, targetDatasets: [dataset_id]})

      Brook.Event.send(@instance_name, ingestion_update(), __MODULE__, ingestion)

      eventually(fn ->
        persisted_ingestion = Ingestions.get(ingestion_id)
        assert persisted_ingestion != nil
        assert persisted_ingestion.id == ingestion.id
      end)
    end
  end

  describe "Ingestion Delete - happy path" do
    test "successfully deletes ingestion" do
      dataset_id = UUID.uuid4()
      dataset = TDG.create_dataset(%{id: dataset_id})
      Brook.Event.send(@instance_name, dataset_update(), __MODULE__, dataset)

      eventually(fn ->
        assert Datasets.get(dataset_id) != nil
      end)

      ingestion_id = UUID.uuid4()
      ingestion = TDG.create_ingestion(%{id: ingestion_id, targetDatasets: [dataset_id]})
      Brook.Event.send(@instance_name, ingestion_update(), __MODULE__, ingestion)

      eventually(fn ->
        assert Ingestions.get(ingestion_id) != nil
      end)

      # Now delete it
      Brook.Event.send(@instance_name, ingestion_delete(), __MODULE__, ingestion)

      eventually(fn ->
        assert Ingestions.get(ingestion_id) == nil
      end)
    end
  end

  describe "Organization Update - happy path" do
    test "successfully processes and persists organization" do
      org_id = UUID.uuid4()
      org = TDG.create_organization(%{id: org_id})

      Brook.Event.send(@instance_name, organization_update(), __MODULE__, org)

      eventually(fn ->
        persisted_org = Organizations.get(org_id)
        assert persisted_org != nil
        assert persisted_org.id == org.id
      end)
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
  end

  describe "User org disassociate - happy path" do
    test "successfully disassociates user from organization" do
      org = TDG.create_organization(%{})
      org |> Organization.changeset() |> Organizations.save()

      subject_id = UUID.uuid4()

      {:ok, _user} =
        User.create_or_update(subject_id, %{
          subject_id: subject_id,
          email: "test@test.com",
          name: "Test User"
        })

      # Associate first
      association = %UserOrganizationAssociate{org_id: org.id, subject_id: subject_id, email: "test@test.com"}
      Brook.Event.send(@instance_name, user_organization_associate(), __MODULE__, association)

      eventually(fn ->
        user = User.get_by_subject_id(subject_id)
        assert user.organizations |> Enum.map(fn o -> o.id end) |> Enum.member?(org.id)
      end)

      # Now disassociate
      disassociation = %UserOrganizationDisassociate{org_id: org.id, subject_id: subject_id}
      Brook.Event.send(@instance_name, user_organization_disassociate(), __MODULE__, disassociation)

      eventually(fn ->
        user = User.get_by_subject_id(subject_id)
        is_member = user.organizations |> Enum.map(fn o -> o.id end) |> Enum.member?(org.id)
        assert is_member == false
      end)
    end
  end

  describe "Dataset Delete - happy path" do
    test "successfully deletes dataset" do
      dataset_id = UUID.uuid4()
      dataset = TDG.create_dataset(%{id: dataset_id})

      Brook.Event.send(@instance_name, dataset_update(), __MODULE__, dataset)

      eventually(fn ->
        assert Datasets.get(dataset_id) != nil
      end)

      Brook.Event.send(@instance_name, dataset_delete(), __MODULE__, dataset)

      eventually(fn ->
        assert Datasets.get(dataset_id) == nil
      end)
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
  end

  describe "#{event_log_published()}" do
    test "The event log is persisted to the postgres table" do
      my_time = DateTime.to_iso8601(DateTime.utc_now())

      event_log = %SmartCity.EventLog{
        title: "someTitle",
        timestamp: my_time,
        description: "someStuff",
        source: "fromATest",
        dataset_id: UUID.uuid4(),
        ingestion_id: UUID.uuid4()
      }

      Brook.Event.send(@instance_name, event_log_published(), __MODULE__, event_log)

      {:ok, event_log_datetime, _} = DateTime.from_iso8601(event_log.timestamp)
      expected_timestamp = DateTime.truncate(event_log_datetime, :microsecond)

      eventually(fn ->
        [persisted_event_log | _tail] = Andi.InputSchemas.EventLogs.get_all_for_dataset_id(event_log.dataset_id)
        assert persisted_event_log.dataset_id == event_log.dataset_id
        assert persisted_event_log.ingestion_id == event_log.ingestion_id
        assert persisted_event_log.title == event_log.title
        assert persisted_event_log.timestamp == expected_timestamp
        assert persisted_event_log.source == event_log.source
        assert persisted_event_log.description == event_log.description
      end)
    end

    test "Event Log Published event handler deletes records older than 7 days" do
      old_time =
        DateTime.to_iso8601(
          DateTime.add(
            DateTime.utc_now(),
            -9 *
              3600 * 24,
            :second
          )
        )

      old_event_log = %SmartCity.EventLog{
        title: "someTitle",
        timestamp: old_time,
        description: "someStuff",
        source: "fromATest",
        dataset_id: UUID.uuid4(),
        ingestion_id: UUID.uuid4()
      }

      Brook.Event.send(@instance_name, event_log_published(), __MODULE__, old_event_log)

      eventually(fn ->
        assert 1 == length(Andi.InputSchemas.EventLogs.get_all())
      end)

      new_event_log = %{old_event_log | timestamp: DateTime.to_iso8601(DateTime.utc_now()), description: "someOtherStuff"}

      {:ok, event_log_datetime, _} = DateTime.from_iso8601(new_event_log.timestamp)
      expected_timestamp = DateTime.truncate(event_log_datetime, :microsecond)

      Brook.Event.send(@instance_name, event_log_published(), __MODULE__, new_event_log)

      eventually(fn ->
        all_datasets = Andi.InputSchemas.EventLogs.get_all()
        assert length(all_datasets) == 1
        [persisted_event_log | _tail] = all_datasets
        assert persisted_event_log.dataset_id == new_event_log.dataset_id
        assert persisted_event_log.description == new_event_log.description
      end)
    end

    test "Event Log Published event handler does not delete records from 7 days or newer" do
      old_time =
        DateTime.to_iso8601(
          DateTime.add(
            DateTime.utc_now(),
            -7 *
              3600 * 24,
            :second
          )
        )

      old_event_log = %SmartCity.EventLog{
        title: "someTitle",
        timestamp: old_time,
        description: "someStuff",
        source: "fromATest",
        dataset_id: UUID.uuid4(),
        ingestion_id: UUID.uuid4()
      }

      Brook.Event.send(@instance_name, event_log_published(), __MODULE__, old_event_log)

      eventually(fn ->
        assert 1 == length(Andi.InputSchemas.EventLogs.get_all())
      end)

      new_event_log = %{old_event_log | timestamp: DateTime.to_iso8601(DateTime.utc_now()), description: "someOtherStuff"}

      {:ok, event_log_datetime, _} = DateTime.from_iso8601(new_event_log.timestamp)
      expected_timestamp = DateTime.truncate(event_log_datetime, :microsecond)

      Brook.Event.send(@instance_name, event_log_published(), __MODULE__, new_event_log)

      eventually(fn ->
        all_datasets = Andi.InputSchemas.EventLogs.get_all()
        assert length(all_datasets) == 1
        [persisted_event_log | _tail] = all_datasets
        assert persisted_event_log.dataset_id == new_event_log.dataset_id
        assert persisted_event_log.description == new_event_log.description
      end)
    end
  end

  describe "#{ingestion_complete()}" do
    test "The ingestion_complete event is transformed into a message error struct and persisted to the postgres table" do
      dataset_id = UUID.uuid4()
      ingestion_id = UUID.uuid4()
      extraction_start_time = DateTime.truncate(DateTime.utc_now(), :second)

      ingestion_complete_event = %{
        "ingestion_id" => ingestion_id,
        "dataset_id" => dataset_id,
        "expected_message_count" => 3,
        "actual_message_count" => 0,
        "extraction_start_time" => extraction_start_time
      }

      Brook.Event.send(@instance_name, ingestion_complete(), __MODULE__, ingestion_complete_event)

      eventually(fn ->
        message_error = Andi.InputSchemas.MessageErrors.get_latest_error(dataset_id)
        assert message_error.dataset_id == dataset_id
        assert message_error.ingestion_id == ingestion_id
        assert message_error.has_current_error == true
        assert message_error.last_error_time == extraction_start_time
      end)
    end

    test "ingestion_complete event handler deletes records older than 7 days" do
      old_dataset_id = UUID.uuid4()
      new_dataset_id = UUID.uuid4()
      ingestion_id = UUID.uuid4()

      old_time =
        DateTime.truncate(
          DateTime.add(
            DateTime.utc_now(),
            -9 * 3600 * 24,
            :second
          ),
          :second
        )

      new_time =
        DateTime.add(
          DateTime.utc_now(),
          -7 *
            3600 * 24,
          :second
        )

      old_message_error = %{
        ingestion_id: ingestion_id,
        dataset_id: old_dataset_id,
        has_current_error: true,
        last_error_time: old_time
      }

      MessageErrors.update(old_message_error)

      current_error = MessageErrors.get_latest_error(old_dataset_id)
      assert current_error.dataset_id == old_dataset_id
      assert current_error.ingestion_id == ingestion_id
      assert current_error.has_current_error == true
      assert current_error.last_error_time == old_time

      ingestion_complete_event = %{
        "ingestion_id" => ingestion_id,
        "dataset_id" => new_dataset_id,
        "expected_message_count" => 3,
        "actual_message_count" => 0,
        "extraction_start_time" => new_time
      }

      Brook.Event.send(@instance_name, ingestion_complete(), __MODULE__, ingestion_complete_event)

      eventually(fn ->
        current_error = MessageErrors.get_latest_error(old_dataset_id)
        # returns default values
        assert current_error.dataset_id == old_dataset_id
        assert current_error.ingestion_id == nil
        assert current_error.has_current_error == false
        assert current_error.last_error_time == DateTime.from_unix!(0)
      end)
    end
  end
end
