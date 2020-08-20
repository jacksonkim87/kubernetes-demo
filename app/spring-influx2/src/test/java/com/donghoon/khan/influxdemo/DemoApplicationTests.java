package com.donghoon.khan.influxdemo;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;

import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.Random;

import com.donghoon.khan.influxdemo.entity.Temperature;
import com.donghoon.khan.influxdemo.repository.TemperatureRepository;

import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.TestInstance;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;

@SpringBootTest
@TestInstance(TestInstance.Lifecycle.PER_CLASS)
class DemoApplicationTests {

    @Autowired
    TemperatureRepository temperatureRepository;

    private Temperature temperatureEntity;
    private List<Temperature> temperatureEntities;

    @BeforeAll
    public void setUp() throws Exception {

        Random rand = new Random();
        String[] location = {
            "Seoul",
            "Seongnam",
            "Daegu",
            "Gwangju",
            "Busan"
        };

        temperatureEntity = Temperature.builder()
                .time(Instant.now())
                .location("Seoul")
                .value(rand.nextDouble() * 10.0)
                .build();

        temperatureEntities = new ArrayList<>();
        for (int i = 0; i < 100; i ++) {
            Temperature entity = Temperature.builder()
                    .time(Instant.now())
                    .location(location[i % 5])
                    .value((rand.nextDouble() + 0.001) * 100.0)
                    .build();
            temperatureEntities.add(entity);
        }
    }

	@Test
	public void saveTemperatureEntity() throws Exception {
        temperatureRepository.save(temperatureEntity);
        List<Temperature> entities = 
                temperatureRepository.findByLocation(temperatureEntity.getLocation());
        for (Temperature entity : entities) {
            assertNotEquals(0, entity.getValue());
        }
    }

    @Test
	public void saveTemperatureEntities() throws Exception {
        temperatureRepository.save(temperatureEntities);
        List<Temperature> entities = 
                temperatureRepository.findByLocation("Seoul");
        for (Temperature entity : entities) {
            assertNotEquals(0, entity.getValue());
        }
    }
}
