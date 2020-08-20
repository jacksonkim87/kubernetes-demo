package com.donghoon.khan.influxdemo.entity;

import java.time.Instant;

import com.influxdb.annotations.Column;
import com.influxdb.annotations.Measurement;

import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

@Getter
@Setter
@NoArgsConstructor
@Measurement(name = "Temperature")
public class Temperature {

    @Column(timestamp = true)
    Instant time;

    @Column(tag = true)
    String location;

    @Column
    Double value;

    @Builder
    public Temperature(Instant time, String location, Double value) {
        this.time = time;
        this.location = location;
        this.value = value;
    }
}