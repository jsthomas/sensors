# sensors

This repo implements a simple REST API server using the
[Dream](https://aantron.github.io/dream/) web framework. I wrote it in
July of 2021, while I was at the [Recurse
Center](https://www.recurse.com/), in order to learn more about web
programming in OCaml.

I wrote an accompanying [blog
post](https://jsthomas.github.io/ocaml-dream-api.html) that explains
some of my build process and compares the experience to building web
applications in Python.

## What does the server do?

The `sensors` server provides a simple API for managing time series
data. A "sensor" is an abstract IoT device that measures a floating
point quantity at a specific cadence (for example a weather station
producing an hourly average wind-speed reading).

The API sends and receives data formatted as JSON, and stores
information in a PostgreSQL database. It allows creating, reading, and
deleting of "sensors". Each sensor has an API key, which grants the
ability to upload (POST) data to an endpoint. API users can use a GET
endpoint to retrieve sensor readings between two dates. A more
detailed description of the API endpoints is available
[here](api_doc.md).

There are three main entities in the system: Users, Sensors, and
Readings. A user can "own" several sensors, and each sensor can have
many readings. A single reading record consists of a date and a
(chronological) array of readings taken on that date (e.g. an hourly
sensor has an array of 24 elements).

*Important:* This project shouldn't be used as a reference for
implementing security features (e.g. passwords, API keys). I'm not a
security expert and I spent little time on these types of features.

## How do I get set up?

This project uses a PostgreSQL database in a docker container. Before
running the server, you'll need to install `docker` and
`docker-compose`. Then run `docker-compose up -d`, which should
download the relevant image and start it.

The folder `db` contains scripts for managing the database. From the
root of the project, run `./db/loadschema.sh` to set up the necessary
tables (defined in `db/schema.sql`). You can also run `./db/psql.sh`
to start a client and examine the database.

Assuming you have `dune` [installed](https://dune.build/install), you
should be able to run the server via

```
opam install caqti-driver-postgresql caqti-lwt dream lwt_ppx ppx_yojson_conv ptime re
dune exec server/bin/server
```

I built this project with version 4.11.1 of the compiler.

I used [insomnia](https://insomnia.rest/) to make ad-hoc requests
against the API; the project contains an `insomnia.yaml` file, if
you'd like to use my existing API setup.

## How do I shut the database down (or restart it)?

After stopping the server (CRTL+C), run `docker-compose down`. This
should shut down the PostgreSQL container (and clear any state in the
DB).

## Project Structure

- `server/lib` contains utility functions for dealing with dates and
  times.
- `server/models` contains `Caqti` queries for the four main tables in
  the database (Keys, Users, Sensors, and Readings).
- `server/bin` defines the server itself.

(Files are stored under `server` because I'm considering adding a
frontend portion to this project in the future.)

## Feedback

If you ended up looking through the source code for my API, let me
know how what you thought! I'm interested in adding more tutorial
resources to the OCaml ecosystem, so feel free to post a PR or issue
if you have ideas about how to make these resources better.
