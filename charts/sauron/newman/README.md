# Newman Tests
## What is this

These tests work via newman, a postman cli. It makes a series of calls to our services and runs tests against the calls.

Newman Tests run against production and goes from Andi Org creation through Discovery API retrieval. The number of failures goes to the terminal, and test results are saved to a file called "results" so the failures can be examined

## To Import to Postman

- Download and Install Postman - https://www.postman.com/downloads/
- Import the file `e2e_test.postman_collection.json` (done with `Command + O` on Mac)
- Manipulate calls, see tests by clicking on each call.
- Check the pre-script for each call, they all add delays when running the full suite to allow time for the calls to make it through the system
- Also check the environment variables for the entire collection to change where the suite is run against (i.e. against local, or a new environment) 

## To Run the suite
- Enter Sauron (in environment or locally)
  - Find the name of a previously run sauron cron pod - i.e:
```shell
oc debug sauron-cron-27900780--1-847ds
```
- Enter VPN (if local)
- navigate to /usr/local/bin
- Specify your postman environment vars and your output file:
```shell
newman run e2e_test.postman_collection.json --insecure --delay-request 2000 \
    --reporters json --reporter-json-export {path_to_output_file}.json --env-var "andi_url={andi_url} discovery_url={discovery_url} api_key={api_key}" 
```

- Once completed, extract any errors from the results file:
```shell
./extract_errors.sh {path_to_results_file}.json
```


## What all is done

Makes the following calls and asserts against them 
- Org Create
- Dataset Create
- Ingestion Create (hits https://raw.githubusercontent.com/bmitchinson/json-endpoint/main/meters_ingestionA.json)
- Ingestion Publish
- Discovery API Get (checks results from that ingestion)
- Ingestion Delete
- Dataset Delete

Other features of this suite -
- Waiting appropriate time per call
- Tests against each call checking the status and returned value
- Randomly assigning guids to Ingestion and Dataset to avoid conflict
- Runs in Sauron in order to be within the Cluster
- Easily able to be ported to locally by importing to postman

## Possible Additions
- xml data
- csv data
- monitoring topics throughout the process to see where failures happen
- org cleanup (no way to delete orgs currently exists)
- alerts on failure
- adding it to the sauron cron
- adding to other environments, currently hardcoded to values for a single environment
- clearer failure logs (i.e. not having to enter the results file and finding them)
- speed up runtime by having kafka run batches more frequently (currently takes about 3 minutes, could easily be cut down to a single minute if kafka was snappier)

