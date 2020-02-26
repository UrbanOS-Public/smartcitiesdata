# Discovery Tableau Web Data Connector

## Usage
To utilize this connector in Tableau Enterprise, Public, etc. add a connector with the URL: https://data.smartcolumbusos.com/tableau/connector.html


## Local Development
### Running tests
```sh
npm install
npm test
```

### Check JS against ES5
We are supporting a version of Tableau that runs the web data connector in an older version of Internet Explorer. Because of this we need to ship `connector.js` (and any other production code) as ES5 compliant. We ensure that we have proper ES5 javascript using the `es-check` library as part of the build.  Run this check locally with:
```sh
npm run es-check
```

### Running in Web Data Connector Simulator
Run Discovery API locally (see its [README](../../../README.md)).

-or-

Serve only the connector locally
```sh
npm install -g http-server
http-server .
```

Install the simulator
```sh
git clone https://github.com/tableau/webdataconnector.git
cd webdataconnector
npm install
npm start
```

Open the simulator in your browser at http://localhost:8888/Simulator

Enter the locally hosted connector URL into the "Connector URL" input field. Example: http://localhost:4000/tableau/connector.html

### Running with Tableau Public in Debug Mode
Run Discovery API locally (see its [README](../../../README.md)).

-or-

Serve only the connector locally
```sh
npm install -g http-server
http-server .
```

Install Tableau Public by downloading from https://public.tableau.com/en-us/s/

Run Tableau Public in debug mode (Mac example)
```sh
open /Applications/Tableau\ Public.app/ --args --remote-debugging-port=9999
```

Access the debugger via http://localhost:9999. Note that the debugger does not run the connector. You must first use the connector with simulator or a Tableau desktop product before seeing output. Also note that Tableau desktop products will cache the connector so you will need to restart it if making changes to the connector.
