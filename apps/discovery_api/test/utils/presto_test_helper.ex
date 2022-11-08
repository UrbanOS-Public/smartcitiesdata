defmodule PrestoTestHelper do
  @moduledoc """
  Helper module for presto related tests
  """
  alias SmartCity.Dataset

  def create_small_test_table(%Dataset{technical: %{systemName: system_name}}) do
    "create table if not exists hive.default.#{system_name} (name varchar, age int)"
  end

  def insert_small_sample_data(%Dataset{technical: %{systemName: system_name}}) do
    "Insert into hive.default.#{system_name} (name, age) values
    ('Alex Trebek', 78),
    ('Pat Sajak', 72),
    ('Wayne Brady', null)
    "
  end

  def create_test_table(%Dataset{technical: %{systemName: system_name}}) do
    "create table if not exists hive.default.#{system_name} (bikes_allowed int, block_id int, direction_id int, route_id int, service_id int, shape_id int, trip_headsign varchar, trip_id int, trip_short_name varchar, wheelchair_accessible int)"
  end

  def insert_sample_data(%Dataset{technical: %{systemName: system_name}}) do
    "Insert into hive.default.#{system_name} (route_id, service_id, trip_id, trip_headsign, trip_short_name, direction_id, block_id, shape_id, wheelchair_accessible, bikes_allowed) values
    (1, 1, 627426, '1 KENNY LIVINGSTON TO REYNOLDSBURG PARK AND RIDE', '', 0, 342116, 45934, 0, 0),
    (35, 1, 635115, '35 DUBLIN GRANVILLE TO EASTON TRANSIT CENTER', '', 0, 343107, 46111, 0, 0),
    (10, 2, 631794, '10 EAST AND WEST BROAD TO WESTWOODS PARK AND RIDE', '', 1, 342650, 46055, 0, 0),
    (35, 1, 635129, '35 DUBLIN GRANVILLE TO STATE ROUTE 161 AND BUSCH', '', 1, 343106, 46112, 0, 0),
    (41, 1, 635217, '41 CROSSWOODS POLARIS TO CROSSWOODS PARK AND RIDE', '', 0, 343117, 46113, 0, 0),
    (42, 1, 635285, '42 SHARON WOODS TO DOWNTOWN', '', 1, 343127, 46122, 0, 0),
    (43, 1, 635299, '43 WESTERVILLE VIA NORTHLAND TRANSIT CENTER TO WESTERVILLE PARK AND RIDE', '', 0, 342220, 46123, 0, 0),
    (10, 2, 631779, '10 EAST AND WEST BROAD TO WESTWOODS PARK AND RIDE', '', 1, 342648, 46056, 0, 0),
    (10, 2, 631781, '10 EAST AND WEST BROAD TO WESTWOODS PARK AND RIDE', '', 1, 342642, 46056, 0, 0),
    (10, 2, 631782, '10 EAST AND WEST BROAD TO WESTWOODS PARK AND RIDE', '', 1, 342646, 46055, 0, 0),
    (43, 1, 635290, '43 WESTERVILLE TO WESTERVILLE PARK AND RIDE', '', 0, 343131, 46124, 0, 0),
    (43, 1, 635293, '43 WESTERVILLE TO WESTERVILLE PARK AND RIDE', '', 0, 343134, 46124, 0, 0),
    (43, 1, 635305, '43 WESTERVILLE TO DOWNTOWN', '', 1, 343137, 46129, 0, 0),
    (43, 1, 635306, '43 WESTERVILLE TO DOWNTOWN', '', 1, 343138, 46129, 0, 0),
    (51, 1, 635437, '51 REYNOLDSBURG TO REYNOLDSBURG PARK AND RIDE', '', 0, 342894, 46144, 0, 0),
    (51, 1, 635438, '51 REYNOLDSBURG TO REYNOLDSBURG PARK AND RIDE', '', 0, 342959, 46144, 0, 0),
    (51, 1, 642616, '51 REYNOLDSBURG TO DOWNTOWN', '', 1, 343174, 46149, 0, 0),
    (51, 1, 635451, '51 REYNOLDSBURG TO DOWNTOWN', '', 1, 343175, 46149, 0, 0),
    (10, 2, 642232, '10 EAST AND WEST BROAD TO WESTWOODS PARK AND RIDE', '', 1, 342649, 46056, 0, 0),
    (10, 2, 631808, '10 EAST AND WEST BROAD TO WESTWOODS PARK AND RIDE', '', 1, 342643, 46055, 0, 0),
    (35, 1, 635097, '35 DUBLIN GRANVILLE TO EASTON TRANSIT CENTER', '', 0, 343105, 46111, 0, 0)
  "
  end
end
