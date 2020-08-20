package com.donghoon.khan.influxdemo.repository;

import java.util.ArrayList;
import java.util.List;

import com.donghoon.khan.influxdemo.entity.Temperature;
import com.influxdb.client.InfluxDBClient;
import com.influxdb.client.QueryApi;
import com.influxdb.client.WriteApi;
import com.influxdb.client.domain.WritePrecision;
import com.influxdb.query.FluxRecord;
import com.influxdb.query.FluxTable;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Repository;

@Repository
public class TemperatureRepository {
    
    @Value("${spring.influx2.bucket}")
    String bucket;

    @Autowired
    private InfluxDBClient influx;

    public void save(final Temperature entity) {
        final WriteApi writeApi = influx.getWriteApi();
        writeApi.writeMeasurement(WritePrecision.US, entity);
    }

    public void save(final List<Temperature> entities) {
        final WriteApi writeApi = influx.getWriteApi();
        writeApi.writeMeasurements(WritePrecision.US, entities);
    }

    public List<Temperature> findByLocation(String location) {
        List<Temperature> entities = new ArrayList<>();
        String query = "from(bucket:" + "\"" + bucket + "\")"
                + "|> range(start: 0)"
                + "|> filter(fn:(r) => r[\"_measurement\"] == " + "\"Temperature\")"
                + "|> filter(fn:(r) => r[\"location\"] == " + "\"" + location + "\")"
                + "|> sort(columns: [\"_time\"])";
        final QueryApi queryApi = influx.getQueryApi();
        final List<FluxTable> tables = queryApi.query(query);
        for (final FluxTable fluxTable : tables) {
            final List<FluxRecord> records = fluxTable.getRecords();
            for (final FluxRecord fluxRecord : records) {
                Temperature entity = new Temperature();
                entity.setTime(fluxRecord.getTime());
                entity.setValue(Double.parseDouble(fluxRecord.getValueByKey("_value").toString()));
                entities.add(entity);
            }
        }
        return entities;
    }
}