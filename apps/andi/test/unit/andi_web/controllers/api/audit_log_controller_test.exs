defmodule AndiWeb.API.AuditLogControllerTest do
  use AndiWeb.Test.AuthConnCase.UnitCase
  use Placebo

  alias Andi.Schemas.AuditEvents
  alias Andi.Schemas.AuditEvent
  @route "/api/v1/audit"
  @error_text "Unsupported request. Only one filter can be used at a time - 'user_id', 'audit_id', 'type', 'event_id.'" <>
                "For time, exactly 'start_date' and 'end_date' must be used and formatted in ISO-8601. ex. /start_date=2020-12-31&end-date=2021-01-01"

  setup %{} do
    logs = [
      struct(AuditEvent, %{
        id: "id",
        user_id: "user_id",
        event_type: "event_type",
        event: %{
          id: "event id",
          list: [
            deeply_nested_data: %{
              deep_data: "deep"
            },
            list_data: "list"
          ]
        }
      }),
      struct(AuditEvent, %{
        id: "id",
        user_id: "user_id",
        event_type: "event_type",
        event: %{
          data: "some data",
          other_data: "some other_data"
        }
      })
    ]

    logs_as_text = """
    %{event: %{id: \"event id\", list: [deeply_nested_data: %{deep_data: \"deep\"}, list_data: \"list\"]}, event_type: \"event_type\", id: \"id\", inserted_at: nil, updated_at: nil, user_id: \"user_id\"}
    %{event: %{data: \"some data\", other_data: \"some other_data\"}, event_type: \"event_type\", id: \"id\", inserted_at: nil, updated_at: nil, user_id: \"user_id\"}
    """

    [logs: logs, logs_as_text: logs_as_text]
  end

  test "get all audit logs", %{conn: conn, logs: logs, logs_as_text: logs_as_text} do
    allow(AuditEvents.get_all(), return: logs)
    conn = get(conn, "#{@route}")

    assert_called(AuditEvents.get_all())

    assert response(conn, 200) =~ logs_as_text
  end

  test "get by audit id", %{conn: conn, logs: logs, logs_as_text: logs_as_text} do
    audit_id = "12345"
    allow(AuditEvents.get(audit_id), return: logs)
    conn = get(conn, "#{@route}?audit_id=#{audit_id}")

    assert_called(AuditEvents.get(audit_id))

    assert response(conn, 200) =~ logs_as_text
  end

  test "get by user id", %{conn: conn, logs: logs, logs_as_text: logs_as_text} do
    user_id = "user_id"
    allow(AuditEvents.get_all_for_user(user_id), return: logs)
    conn = get(conn, "#{@route}?user_id=#{user_id}")

    assert_called(AuditEvents.get_all_for_user(user_id))

    assert response(conn, 200) =~ logs_as_text
  end

  test "get by type", %{conn: conn, logs: logs, logs_as_text: logs_as_text} do
    type = "some_type"
    allow(AuditEvents.get_all_of_type(type), return: logs)
    conn = get(conn, "#{@route}?type=#{type}")

    assert_called(AuditEvents.get_all_of_type(type))

    assert response(conn, 200) =~ logs_as_text
  end

  test "get by event id", %{conn: conn, logs: logs, logs_as_text: logs_as_text} do
    event_id = "54321"
    allow(AuditEvents.get_all_by_event_id(event_id), return: logs)
    conn = get(conn, "#{@route}?event_id=#{event_id}")

    assert_called(AuditEvents.get_all_by_event_id(event_id))

    assert response(conn, 200) =~ logs_as_text
  end

  test "filter by dates", %{conn: conn, logs: logs, logs_as_text: logs_as_text} do
    {:ok, start_date_struct} = Date.new(2020, 6, 5)
    {:ok, end_date_struct} = Date.new(2020, 10, 9)
    allow(AuditEvents.get_all_in_range(start_date_struct, end_date_struct), return: logs)

    conn = get(conn, "#{@route}?start_date=2020-06-05&end_date=2020-10-09")

    assert_called(AuditEvents.get_all_in_range(start_date_struct, end_date_struct))
    assert response(conn, 200) =~ logs_as_text
  end

  test "returns error when given multiple arguments", %{conn: conn} do
    conn = get(conn, "#{@route}?event_id=event&type=type")

    assert response(conn, 400) =~ @error_text
  end

  test "returns error when given unsupported argument", %{conn: conn} do
    conn = get(conn, "#{@route}?foobar=foo")

    assert response(conn, 400) =~ @error_text
  end
end
