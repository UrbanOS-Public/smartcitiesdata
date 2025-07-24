# Overview

Tasks for Gemini

I am migrating this project from OTP23 to OTP25.

I am also replacing the Placebo component in unit tests with Mox. Please help me with this project.

## Pending Tasks


- The apps/discovery_streams unit tests are failing. Please revise the tests to work without placebo, use mox instead and restore the unit tests to a passing state.



## Deferred Tasks

- Replace Placebo component in unit tests with Mox and other components.
- Fix all existing apps/forklift unit tests so they pass while preserving the essence of the tests.

## Completed Tasks

- Currently "mix compile" in the top level project directory with an incompatibility of nimble_csv 1.3.0 with Elixir 1.4. Focus on the nimble_csv problem first.
-  apps/forklift unit tests are failing. Please correct message_handling_test.exs unit test failures.
- The apps/dlq unit tests are failing. Please make them pass.
- The apps/raptor_service unit tests are failing. Please revise the tests to work without placebo, use mox instead and restore the unit tests to a passing state.
- The apps/template unit tests are failing. Please revise the tests to work without placebo, use mox instead and restore the unit tests to a passing state.
- The apps/definition unit tests are failing. Please revise the tests to work without placebo, use mox instead and restore the unit tests to a passing state.
- The apps/auth unit tests are failing. Please revise the tests to work without placebo, use mox instead and restore the unit tests to a passing state.
- The apps/definition_kafka unit tests are failing. Please revise the tests to work without placebo, use mox instead and restore the unit tests to a passing state.
- It appears there is currently a compilation error in apps/definition_kafka. The problem is likely due to this:
  The definition_kafka app has a dependency on protocol_destination, but it seems like the compiler is not correctly picking up the Destination.Context struct.

  I will try to fix this by adding protocol_destination to the list of applications in apps/definition_kafka/mix.exs. This will ensure that the protocol_destination application is started before the definition_kafka application, which should make the
- The apps/estuary unit tests are failing. Please revise the tests to work without placebo, use mox instead and restore the unit tests to a passing state.
