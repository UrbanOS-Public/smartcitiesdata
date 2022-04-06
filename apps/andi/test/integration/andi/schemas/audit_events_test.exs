defmodule Andi.Schemas.AuditEventsTest do
  use ExUnit.Case
  use Andi.DataCase

  @moduletag shared_data_connection: true

  alias SmartCity.TestDataGenerator, as: TDG
  import SmartCity.Event

  alias Andi.Schemas.AuditEvents
  alias Andi.Schemas.AuditEvent
  alias Andi.Schemas.User

  describe "get_all/0" do
    test "given existing audit events, all are returned" do
      audit_event_id_1 = UUID.uuid4()
      audit_event_id_2 = UUID.uuid4()
      dataset_one = TDG.create_dataset(%{})
      dataset_two = TDG.create_dataset(%{})

      Andi.Schemas.AuditEvents.create(%{id: audit_event_id_1, user_id: "auth0|1", event_type: dataset_update(), event: dataset_one})
      Andi.Schemas.AuditEvents.create(%{id: audit_event_id_2, user_id: "auth0|2", event_type: dataset_update(), event: dataset_two})

      assert [%{id: ^audit_event_id_1}, %{id: ^audit_event_id_2} | _] = AuditEvents.get_all()
    end
  end

  describe "get/1" do
    test "given an existing audit event, it returns it" do
      audit_event_id_1 = UUID.uuid4()
      dataset_one = TDG.create_dataset(%{})
      dataset_one_json = dataset_one |> Jason.encode!() |> Jason.decode!()

      Andi.Schemas.AuditEvents.create(%{id: audit_event_id_1, user_id: "auth0|1", event_type: dataset_update(), event: dataset_one})

      assert %{
               id: ^audit_event_id_1,
               user_id: "auth0|1",
               event_type: dataset_update(),
               event: ^dataset_one_json
             } = AuditEvents.get(audit_event_id_1)
    end

    test "given a non-existing audit event, it returns nil" do
      assert nil == AuditEvents.get(UUID.uuid4())
    end
  end

  describe "create/0" do
    test "given new audit event, creates an audit event" do
      audit_event_id = UUID.uuid4()
      dataset = TDG.create_dataset(%{})
      changeset = %{id: audit_event_id, user_id: "auth0|1", event_type: dataset_update(), event: dataset}

      new_audit_event = AuditEvents.create(changeset)
      audit_event_in_db = AuditEvents.get(audit_event_id)

      assert audit_event_in_db.id == new_audit_event.id
      assert audit_event_in_db.user_id == new_audit_event.user_id
      assert audit_event_in_db.event_type == new_audit_event.event_type
      assert audit_event_in_db.event == new_audit_event.event |> Jason.encode!() |> Jason.decode!()
    end
  end

  describe "log_audit_event/3" do
    test "given new audit event for an api user, creates an audit event" do
      dataset = TDG.create_dataset(%{})
      event = AuditEvents.log_audit_event(:api, dataset_update(), dataset)

      audit_event_in_db = AuditEvents.get(event.id)

      assert audit_event_in_db.id == event.id
      assert audit_event_in_db.user_id == "api"
      assert audit_event_in_db.event_type == dataset_update()
      assert audit_event_in_db.event == dataset |> Jason.encode!() |> Jason.decode!()
    end

    test "given new audit event for a non-api user, creates an audit event with the user email address" do
      user_subject_id = Ecto.UUID.generate()
      {:ok, %{id: id}} = User.create_or_update(user_subject_id, %{email: "penny@woof.com", name: "Penny"})

      dataset = TDG.create_dataset(%{})
      event = AuditEvents.log_audit_event(id, dataset_update(), dataset)

      audit_event_in_db = AuditEvents.get(event.id)

      assert audit_event_in_db.id == event.id
      assert audit_event_in_db.user_id == "penny@woof.com"
      assert audit_event_in_db.event_type == dataset_update()
      assert audit_event_in_db.event == dataset |> Jason.encode!() |> Jason.decode!()
    end
  end

  describe "get_all_for_user/1" do
    test "given an existing audit event for that user, it returns it" do
      audit_event_id_1 = UUID.uuid4()
      dataset_one = TDG.create_dataset(%{})
      dataset_one_json = dataset_one |> Jason.encode!() |> Jason.decode!()

      Andi.Schemas.AuditEvents.create(%{id: audit_event_id_1, user_id: "auth0|1701", event_type: dataset_update(), event: dataset_one})

      assert [
               %{
                 id: ^audit_event_id_1,
                 user_id: "auth0|1701",
                 event_type: dataset_update(),
                 event: ^dataset_one_json
               }
             ] = AuditEvents.get_all_for_user("auth0|1701")
    end

    test "given there are no audit events for the user, it returns an empty list" do
      assert [] == AuditEvents.get_all_for_user("auth0|invalid-user")
    end
  end

  describe "get_all_of_type/1" do
    test "given an existing audit event for the event type, it returns it" do
      audit_event_id_1 = UUID.uuid4()
      org = TDG.create_organization(%{})
      org_json = org |> Jason.encode!() |> Jason.decode!()

      Andi.Schemas.AuditEvents.create(%{id: audit_event_id_1, user_id: "auth0|1701D", event_type: "test:event", event: org})

      assert [
               %{
                 id: ^audit_event_id_1,
                 user_id: "auth0|1701D",
                 event_type: "test:event",
                 event: ^org_json
               }
             ] = AuditEvents.get_all_of_type("test:event")
    end

    test "given there are no audit events for the event type, it returns an empty list" do
      assert [] == AuditEvents.get_all_of_type("event-with-no-audit-records")
    end
  end

  describe "get_all_by_event_id/1" do
    test "given existing audit events for the event id, it returns it" do
      audit_event_id_1 = UUID.uuid4()
      audit_event_id_2 = UUID.uuid4()
      org = TDG.create_organization(%{})
      org_json = org |> Jason.encode!() |> Jason.decode!()

      Andi.Schemas.AuditEvents.create(%{id: audit_event_id_1, user_id: "auth0|1701A", event_type: organization_update(), event: org})
      Andi.Schemas.AuditEvents.create(%{id: audit_event_id_2, user_id: "auth0|1701A", event_type: organization_update(), event: org})

      assert [
               %{
                 id: ^audit_event_id_1,
                 user_id: "auth0|1701A",
                 event_type: organization_update(),
                 event: ^org_json
               },
               %{
                 id: ^audit_event_id_2,
                 user_id: "auth0|1701A",
                 event_type: organization_update(),
                 event: ^org_json
               }
             ] = AuditEvents.get_all_by_event_id(org.id)
    end

    test "given there are no audit events with the given event id, it returns an empty list" do
      assert [] == AuditEvents.get_all_by_event_id(UUID.uuid4())
    end
  end

  describe "get_all_in_range/1" do
    test "given an existing audit event in the date range, it returns it" do
      start_date = Date.utc_today()
      end_date = Date.utc_today() |> Date.add(1)
      audit_event_id_1 = UUID.uuid4()
      org = TDG.create_organization(%{})
      org_json = org |> Jason.encode!() |> Jason.decode!()

      Andi.Schemas.AuditEvents.create(%{id: audit_event_id_1, user_id: "auth0|1701D", event_type: organization_update(), event: org})

      assert [
               %{
                 id: ^audit_event_id_1,
                 user_id: "auth0|1701D",
                 event_type: organization_update(),
                 event: ^org_json
               }
               | _
             ] = AuditEvents.get_all_in_range(start_date, end_date)
    end

    test "given there are no audit events in the given date range, it returns an empty list" do
      start_date = Date.utc_today() |> Date.add(-14)
      end_date = Date.utc_today() |> Date.add(-13)
      assert [] == AuditEvents.get_all_in_range(start_date, end_date)
    end
  end
end
