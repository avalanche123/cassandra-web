# Cassandra Web

A web interface to Apache Cassandra with AngularJS and server-sent events.

## Installation

```bash
gem install cassandra-web
```

## Usage

Run `cassandra-web -h` for help.

### Quick Start

```bash
cassandra-web
```

### Connect to a Cassandra Cluster requiring authentication

```bash
cassandra-web --hosts '10.0.2.2' --port '9042' --username 'cassweb' --password 'myPassword'
```





## How it works

Cassandra web consists of an HTTP API powered by [Sinatra](https://github.com/sinatra/sinatra) and a thin HTML5/JavaScript frontend powered by [AngularJS](https://angularjs.org/).

When you run `cassandra-web` script, it starts a [Thin web server](http://code.macournoyer.com/thin/) on a specified address, which defaults to `localhost:3000`. Openning `http://localhost:3000`, or whatever address you've specified in the browser, loads the AngularJS application and it starts interacting with the HTTP API of `cassandra-web`. This api uses the [Ruby Driver](http://datastax.github.io/ruby-driver/) to communicate with an [Apache Cassandra](http://cassandra.apache.org/) cluster.

When the frontend has fully loaded, [it subscribes to `/events` API endpoint](https://github.com/avalanche123/cassandra-web/blob/master/app/public/js/cassandra.js#L108), and begins receiving [Server Sent Events](http://www.w3.org/TR/2012/WD-eventsource-20120426/). [The API uses an event listener, which is registered with the `Cluster` instance created by the Ruby Driver, to stream events](https://github.com/avalanche123/cassandra-web/blob/master/app/helpers/sse.rb#L43-L56) such as [schema](https://github.com/avalanche123/cassandra-web/blob/master/app/helpers/sse.rb#L29-L39) and [node status](https://github.com/avalanche123/cassandra-web/blob/master/app/helpers/sse.rb#L13-L27) changes to update the user interface without having to refresh the page.

You can see this feature in action by creating a keyspace using the execute button in the top-right corner of the UI and executing the following statement:

```cql
CREATE KEYSPACE example WITH replication = {'class': 'SimpleStrategy', 'replication_factor': 1}
```

If the statement executed successfully, you should see a new keyspace show up on the left side of the UI.

![Alt text](https://raw.githubusercontent.com/avalanche123/cassandra-web/master/animation.gif "Create Keyspace")

The web server, Thin, used by `cassandra-web` is asynchronous and uses only a single thread to handle requests. This enables efficient handling multiple of long running connections, which is a requirement for streaming and Server Sent Events, but also means that the application cannot perform blocking operations during request handling, since it would hang up all connections for the duration of the blocking operation. `cassandra-web` therefore uses Asynchronous Execution feature of the Ruby Driver to not block on statements execution. [The application executes statements asynchronously, receiving a future from the Ruby Driver](https://github.com/avalanche123/cassandra-web/blob/master/app.rb#L88). [It then registers future completion listeners to send a response (or error) whenever it becomes available](https://github.com/avalanche123/cassandra-web/blob/master/app/helpers/async.rb#L7-L40).

## Credits

Cassandra web is possible because of the following awesome technologies (in no particular order):

* [Apache Cassandra](http://cassandra.apache.org/)
* [DataStax Ruby Driver for Apache Cassandra](http://datastax.github.io/ruby-driver/)
    * [Sinatra](https://github.com/sinatra/sinatra)
    * [AngularJS](https://angularjs.org/)
    * [Twitter Bootstrap](http://getbootstrap.com/)
    * [Thin](http://code.macournoyer.com/thin/)
    * [Server Sent Events](http://www.w3.org/TR/2012/WD-eventsource-20120426/)
    * [PrismJS](http://prismjs.com/)
    * [CodeMirror](http://codemirror.net/)
    * and many others...
