# REST API Endpoints

This document describes all of the endpoints `sensors` supports, with brief examples.

### GET `/version`

Retrieve text indicating the version of the server (e.g. `Sensors
v0.0.0`).

### POST `/api/create_acc`

Create a new user account, provided the credentials in the JSON body are valid.

Example body:
```json
{
	"username": "new_test_user",
  "name": "New test user",
	"password": "new test_password"
}
```

### POST `/api/login`

Start a new session, provided the credentials in the JSON body are valid.

Example body:
```json
{
	"username": "test_user",
	"password": "test_password"
}
```

### POST `/api/logout`

End whatever session that was in progress. No body is required.

### POST `/api/sensor`

Create a new sensor with metadata supplied in the JSON body. The
response body contains the full JSON description of the new sensor,
including a fresh API key for data upload. The `step` field records,
in seconds, how often the sensor takes a measurement.

Example request body:

```json
{
	"name": "API Test Sensor #2",
	"description": "Some new sensor.",
	"step": 3600
}
```

This sensor records data hourly (3600 seconds), producing 24
measurements per day.

Example response body:
```json
{
  "id": 4,
  "name": "API Test Sensor #2",
  "description": "Some new sensor.",
  "api_key": "3b10ddc6-d51e-43e4-b43c-2470b624d5da",
  "step": 3600
}
```


### GET `/api/sensor/<Sensor ID>`

Return the metadata of the sensor specified in the path. The specified
sensor must belong to the user, otherwise the API responds with a `404
Not Found`.

Example response body:
```json
{
  "id": 1,
  "name": "Test Sensor",
  "description": "This is the first example sensor.",
  "api_key": "d08fe36b-06f7-477e-adce-cd96f3d7046a"
}
```

### DELETE `/api/sensor/<Sensor ID>`

Delete the specified sensor, assuming it belongs to the user, and any
related time series data.


### POST `/sensor/upload`

This endpoint is intended for IoT devices to upload their data. The
request should contain an `Authorization` header with the value
`Bearer <API Key>`, where `<API Key>` is the UUID-v4 formatted string
from the sensor's metadata `3b10ddc6-d51e-43e4-b43c-2470b624d5da`
above. If the data was successfully captured, the server responds with
`200 OK`.

Example request body:

```json
[{"time": 1604883600, "value": 1.0},
 {"time": 1604887200, "value": 2.0},
 {"time": 1604890800, "value": 3.0},
 {"time": 1604966400, "value": 8.0},
 {"time": 1604970000, "value": 9.0},
 {"time": 1604973600, "value": 10.0},
 {"time": 1604977200, "value": 11.0},
 {"time": 1604980800, "value": 12.0}]
```

The `time` fields should be epoch timestamps (seconds since midnight,
Jan 1, 1970). The `value` fields should carry whatever floating point
quantity the sensor is measuring. Uploading `null` values is not
allowed.


### POST `/api/sensor/<Sensor ID>/readings`

This endpoint allows a frontend to edit sensor data, and assumes a
session is already active (see `/api/login`). If the data in the
request body is correctly formatted, it completely overwrites the
existing data of data. If the edit was successful, the endpoint
responds with a `200 OK`. If the number of readings does not match the
step size of the sensor, the edit will be rejected.

Example request body:
```json
{
  "occurred": "2020-11-09",
  "readings": [
	4.0, 10.0, 12.0, 9.2, 13.1, 7.6,
	4.0, 10.0, 12.0, 9.2, 13.1, 7.6,
	4.0, 10.0, 12.0, 9.2, 13.1, 7.6,
	4.0, 10.0, 12.0, 9.2, 13.1, 7.6
  ]
}
```

### GET `/api/sensor/<Sensor ID>/readings?start=<YYYY-MM-DD>&end=<YYYY-MM-DD>`

Recover the specified sensor's readings between the two input dates
(inclusive). If `start` and `end` query parameters aren't supplied,
default to today's data. Missing data will be indicated with `null`
values.

Example response body:

```json
[
  {
    "sensor_id": 1,
    "occurred": "2020-11-09",
    "readings": [
      4.0,
      1.0,
      2.0,
      ...
    ]
  },
  {
    "sensor_id": 1,
    "occurred": "2020-11-10",
    "readings": [
      9.199999999999999,
      13.1,
      7.6,
      ...
    ]
  }
]
```

### GET `/api/user`

Report the metadata associated with the user that owns the current
session. The `sensors` array in the response contains the IDs of all
of the sensors belonging to the user.

Example response body:

```json
{
  "username": "test_user",
  "name": "Test User",
  "sensors": [
    1
  ]
}
```
