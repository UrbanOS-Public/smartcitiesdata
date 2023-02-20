defmodule Andi.Event.EventHandlerTest do
  use ExUnit.Case
  use Andi.DataCase
  use Placebo
  use Properties, otp_app: :andi

  import SmartCity.TestHelper
  import SmartCity.Event
  alias SmartCity.UserOrganizationAssociate
  alias Andi.Schemas.User
  alias SmartCity.TestDataGenerator, as: TDG
  alias Andi.InputSchemas.Organization
  alias Andi.InputSchemas.Organizations
  alias Andi.InputSchemas.Datasets
  alias Andi.DatasetCache
  alias DeadLetter
  alias Andi.InputSchemas.Ingestions
  alias Andi.Services.IngestionStore

  @moduletag shared_data_connection: true
  @instance_name Andi.instance_name()
  getter(:kafka_broker, generic: true)

  describe "Dataset Update" do
    test "A failing message gets placed on dead letter queue and discarded" do

      id_for_invalid_dataset = UUID.uuid4()
      invalid_dataset = TDG.create_dataset(%{id: id_for_invalid_dataset})
      allow(DatasetCache.add_dataset_info(invalid_dataset), exec: fn _nh -> raise "nope" end)

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

        failed_messages = Elsa.Fetch.fetch(kafka_broker(), "dead-letters")
          |> elem(2)
          |> Enum.filter(fn message ->
            actual = Jason.decode!(message.value)
            actual["dataset_id"] == id_for_invalid_dataset
          end)

        assert 1 == length(failed_messages)
        end)
    end
  end

  describe "Ingestion Update" do
    test "A failing message gets placed on dead letter queue and discarded" do

      dataset_id = UUID.uuid4()
      dataset = TDG.create_dataset(%{id: dataset_id})

      Brook.Event.send(@instance_name, dataset_update(), __MODULE__, dataset)

      id_for_invalid_ingestion = UUID.uuid4()
      invalid_ingestion = TDG.create_ingestion(%{id: id_for_invalid_ingestion})
      allow(IngestionStore.create_ingestion(invalid_ingestion), exec: fn _nh -> raise "nope" end)

      id = UUID.uuid4()
      valid_ingestion = TDG.create_ingestion(%{id: id, targetDataset: dataset.id})

      Brook.Event.send(@instance_name, ingestion_update(), __MODULE__, invalid_ingestion)
      Brook.Event.send(@instance_name, ingestion_update(), __MODULE__, valid_ingestion)

      eventually(fn ->
        valid_ingestion_from_ecto = Ingestions.get(id)
        assert valid_ingestion_from_ecto != nil
        assert valid_ingestion_from_ecto.id == valid_ingestion.id

        invalid_ingestion_from_ecto = Ingestions.get(id_for_invalid_ingestion)
        assert invalid_ingestion_from_ecto == nil

        failed_messages = Elsa.Fetch.fetch(kafka_broker(), "dead-letters")
          |> elem(2)
          |> Enum.filter(fn message ->
            actual = Jason.decode!(message.value)
            actual["ingestion_id"] == id_for_invalid_ingestion
          end)

        assert 1 == length(failed_messages)
        end)
    end
  end

  describe "Ingestion Delete" do
    test "A failing message gets placed on dead letter queue and discarded" do
      dataset_id = UUID.uuid4()
      dataset = TDG.create_dataset(%{id: dataset_id})

      id_for_invalid_ingestion = UUID.uuid4()
      invalid_ingestion = TDG.create_ingestion(%{id: id_for_invalid_ingestion})
      allow(IngestionStore.delete(id_for_invalid_ingestion), exec: fn _nh -> raise "nope" end)

      Brook.Event.send(@instance_name, ingestion_delete(), __MODULE__, invalid_ingestion)
      Brook.Event.send(@instance_name, dataset_update(), __MODULE__, dataset)

      eventually(fn ->
        valid_dataset_from_ecto = Datasets.get(dataset_id)
        assert valid_dataset_from_ecto != nil
        assert valid_dataset_from_ecto.id == dataset.id

        failed_messages = Elsa.Fetch.fetch(kafka_broker(), "dead-letters")
          |> elem(2)
          |> Enum.filter(fn message ->
            actual = Jason.decode!(message.value)
            actual["ingestion_id"] == id_for_invalid_ingestion
          end)

        assert 1 == length(failed_messages)
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
end
