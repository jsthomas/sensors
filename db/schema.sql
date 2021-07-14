CREATE EXTENSION if not exists "uuid-ossp";

CREATE TABLE dream_session (
  id TEXT PRIMARY KEY,
  label TEXT NOT NULL,
  expires_at REAL NOT NULL,
  payload TEXT NOT NULL
);

CREATE TABLE app_user (
  id SERIAL PRIMARY KEY,
  username TEXT NOT NULL,
  name TEXT NOT NULL,
  password TEXT NOT NULL
);
CREATE UNIQUE INDEX username ON app_user(username);

CREATE TABLE api_key (
  id SERIAL PRIMARY KEY,
  uuid TEXT NOT NULL DEFAULT uuid_generate_v4(),
  last_used TIMESTAMP NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX api_key_uuid ON api_key(uuid);

CREATE TABLE sensor (
  id SERIAL PRIMARY KEY,
  name TEXT NOT NULL,
  description TEXT,
  api_key INTEGER,
  step INTEGER CHECK (step > 0) NOT NULL,
  FOREIGN KEY (api_key) REFERENCES api_key(id)
);

CREATE TABLE sensor_reading (
  id SERIAL PRIMARY KEY,
  sensor INTEGER,
  occurred DATE,
  readings JSON,
  CONSTRAINT fk_sensor_reading_sensor FOREIGN KEY (sensor) references sensor(id) ON DELETE CASCADE
);
CREATE UNIQUE INDEX sensor_reading_sensor_occurred ON sensor_reading(sensor, occurred);

CREATE TABLE user_sensor (
  id SERIAL PRIMARY KEY,
  app_user INTEGER,
  sensor INTEGER,
  CONSTRAINT fk_user_sensor_user
    FOREIGN KEY (app_user)
    REFERENCES app_user(id)
    ON DELETE CASCADE,
  CONSTRAINT fk_user_sensor_sensor
    FOREIGN KEY (sensor)
    REFERENCES sensor(id)
    ON DELETE CASCADE
);

insert into app_user (username, name, password) values ('test_user', 'Test User', 'test_password');
insert into api_key (uuid) values ('73f186a9-a367-4218-a2e8-f89da8e64715');
insert into sensor (name, description, api_key, step) values
       ('Test Sensor', 'This is the first example sensor.', 1, 3600);
insert into user_sensor (app_user, sensor) values (1,1);
