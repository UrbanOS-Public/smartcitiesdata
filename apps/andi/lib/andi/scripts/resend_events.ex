defmodule Andi.Scripts.ResendEvents do
  alias Andi.Schemas.User
  alias SmartCity.UserOrganizationAssociate, as: UOA
  alias Andi.InputSchemas.Datasets
  alias Andi.InputSchemas.Ingestions
  alias Andi.InputSchemas.Organizations
  alias Andi.InputSchemas.InputConverter
  alias Andi.InputSchemas.AccessGroups
  import SmartCity.Event

  def build_org_assocs_for_user(user) do
    user_orgs = user.organizations

    user_orgs |> Enum.map(fn org -> %UOA{org_id: org.id, subject_id: user.subject_id, email: user.email} end)
  end

  def resend_user_org_assoc_events() do
    users = User.get_all()

    users
    |> Enum.each(fn user ->
      build_org_assocs_for_user(user)
      |> Enum.each(fn assoc ->
        Brook.Event.send(:andi, user_organization_associate(), :data_migrator, assoc)
      end)
    end)
  end

  # Sources from Postgres so this works even after a Redis flush.
  # Sleeps 500ms between events to avoid overwhelming downstream Brook consumers (e.g. Forklift)
  # with a burst that causes GenServer call timeouts on slow Presto operations.
  # Uses get/1 (not get_all) so subSchema is fully preloaded via Dataset.preload/1; get_all only
  # does Repo.preload(technical: :schema) which leaves subSchema as Ecto.Association.NotLoaded,
  # causing map-type fields to be published without a :subSchema key and breaking Valkyrie validation.
  def resend_dataset_events(delay_ms \\ 500) do
    Datasets.get_all()
    |> Enum.filter(&(&1.submission_status == :published))
    |> Enum.map(& &1.id)
    |> Enum.map(&Datasets.get/1)
    |> Enum.each(fn andi_dataset ->
      case InputConverter.andi_dataset_to_smrt_dataset(andi_dataset) do
        {:ok, smrt_dataset} ->
          Brook.Event.send(:andi, dataset_update(), :data_migrator, smrt_dataset)
          Process.sleep(delay_ms)

        {:error, reason} ->
          require Logger
          Logger.error("resend_dataset_events: failed to convert dataset #{andi_dataset.id}: #{inspect(reason)}")
      end
    end)
  end

  # Sources from Postgres so this works even after a Redis flush.
  def resend_ingestion_events() do
    Ingestions.get_all()
    |> Enum.filter(&(&1.submissionStatus == :published))
    |> Enum.each(fn andi_ingestion ->
      case InputConverter.andi_ingestion_to_smrt_ingestion(andi_ingestion) do
        {:ok, smrt_ingestion} ->
          Brook.Event.send(:andi, ingestion_update(), :data_migrator, smrt_ingestion)

        {:error, reason} ->
          require Logger
          Logger.error("resend_ingestion_events: failed to convert ingestion #{andi_ingestion.id}: #{inspect(reason)}")
      end
    end)
  end

  # Sources access group membership from Postgres so this works after a Redis flush.
  # Fires user_access_group_associate for every user in each group and
  # dataset_access_group_associate for every dataset in each group, which causes
  # Raptor to repopulate raptor:user_access_group_relation:* and
  # raptor:dataset_access_group_relation:* keys, and Discovery API to restore the
  # accessGroups list on each dataset model.
  def resend_access_group_events() do
    require Logger

    AccessGroups.get_all()
    |> Andi.Repo.preload([:users, :datasets])
    |> Enum.each(fn access_group ->
      Enum.each(access_group.users, fn user ->
        relation = %SmartCity.UserAccessGroupRelation{
          subject_id: user.subject_id,
          access_group_id: access_group.id
        }

        Brook.Event.send(:andi, user_access_group_associate(), :data_migrator, relation)
      end)

      Enum.each(access_group.datasets, fn dataset ->
        relation = %SmartCity.DatasetAccessGroupRelation{
          dataset_id: dataset.id,
          access_group_id: access_group.id
        }

        Brook.Event.send(:andi, dataset_access_group_associate(), :data_migrator, relation)
      end)

      Logger.info(
        "resend_access_group_events: replayed access group #{access_group.id} (#{access_group.name})" <>
          " — #{length(access_group.users)} user(s), #{length(access_group.datasets)} dataset(s)"
      )
    end)
  end

  # Sources from Postgres so this works even after a Redis flush.
  def resend_org_events() do
    Organizations.get_all()
    |> Enum.each(fn andi_org ->
      case InputConverter.andi_org_to_smrt_org(andi_org) do
        {:ok, smrt_org} ->
          Brook.Event.send(:andi, organization_update(), :data_migrator, smrt_org)

        {:error, reason} ->
          require Logger
          Logger.error("resend_org_events: failed to convert org #{andi_org.id}: #{inspect(reason)}")
      end
    end)
  end

  def resend_all_events() do
    resend_org_events()
    resend_user_org_assoc_events()
    resend_dataset_events()
    resend_ingestion_events()
    resend_access_group_events()
  end
end
