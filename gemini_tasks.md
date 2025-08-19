# Overview

Tasks for Gemini

I am migrating this project from OTP23 to OTP25.

I am also replacing the Placebo component in unit tests with Mox. Please help me with this project.

## Pending Tasks

- The apps/flair unit tests are failing. Please revise the tests to work without placebo, use mox instead and restore the unit tests to a passing state.
- Run the unit tests by first executing "cd apps/flair" and then "mix test" and fix any failures.
- Categorize the remaining unit test failures in apps/reaper and group them together for later resolution.
- Analyze the changes staged for commit, summarize them into four sentences or less suitable as a git commit message.
- Please read otp25_migrate_notes.txt file to refresh your context for this project.
- Please amend otp25_migrate_notes.txt files with new found revelant information regarding this migration process

## apps/reaper

  High Priority

  - Category A (DateTimeMock) - 4 failures, straightforward fix, consistent pattern
  - Category C (Dead Letter) - 1 failure, configuration fix

  Medium Priority

  - Category D (Log Capture) - 1 failure, test expectation adjustment
  - Category B (Processor) - 2 failures, requires more complex mocking strategy

  Summary Statistics:

  - Total Failures: 8
  - Success Rate: 271/279 tests (97.1%)
  - Most Common Issue: DateTimeMock configuration (50% of failures)
  - Complexity: Most failures are configuration/mocking issues rather than logic bugs

  These remaining failures are primarily test infrastructure and configuration issues rather than core application logic problems, indicating good overall code quality with just minor test setup adjustments needed.

Previous categories:

  Recommended Resolution Priority:

  1. High Priority: Category 1 (JSON Decoder) - Core functionality issue affecting data processing
  2. Medium Priority: Category 2 (Processor Mocks) - Test infrastructure cleanup needed
  3. Medium Priority: Category 4 (HTTP Downloader) - Integration test stability
  4. Low Priority: Category 3 (Event Handler Timing) - Minor timing issues in tests
  5. Low Priority: Category 5 (Runtime Errors) - Intermittent process errors

- The most critical issue is Category 1 (JSON Decoder Error Handling) as it affects core data processing functionality. The JSON decoder is not properly handling error cases and returning unexpected error types, which could impact production data ingestion workflows.


## Deferred Tasks

- apps/valkyrie unit tests have one failure. DeadLetter.Carrier.Test.receive() doesn't return the required message.
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
- The apps/definition_dictionary unit tests are failing. Please revise the tests to work without placebo, use mox instead and restore the unit tests to a passing state.
- The apps/valkyrie unit tests are failing. Please revise the tests to work without placebo, use mox instead and restore the unit tests to a passing state.
- The apps/pipeline unit tests are failing. Please revise the tests to work without placebo, use mox instead and restore the unit tests to a passing state.
- The apps/raptor unit tests are failing. Please revise the tests to work without placebo, use mox instead and restore the unit tests to a passing state.
- The apps/transformers unit tests are failing. Please revise the tests to work without placebo, use mox instead and restore the unit tests to a passing state.
- The apps/reaper unit tests are failing. Please revise the tests to work without placebo, use mox instead and restore the unit tests to a passing state.
- The apps/discovery_api unit tests are failing. Please revise the tests to work without placebo, use mox instead and restore the unit tests to a passing state.
- Run the unit tests by first executing "cd apps/discovery_api" and then "mix test" and fix any failures.
- The apps/andi unit tests are failing. Please revise the tests to work without placebo, use mox instead and restore the unit tests to a passing state.
- The apps/flair unit tests are failing. Please revise the tests to work without placebo, use mox instead and restore the unit tests to a passing state.
