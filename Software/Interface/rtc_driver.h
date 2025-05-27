/* rtc_driver.h */
#ifndef RTC_DRIVER_H
#define RTC_DRIVER_H

#include <system.h>
#include <io.h>
#include <stdio.h>

typedef unsigned char byte;

// Register addresses for Avalon-I2C core
#define I2C_0_BASE        0x81000
#define CONTROL_REGISTER  0x00  // CONTINUE (bit3), RW (bit2), STOP (bit1), ENABLE (bit0)
#define WRITE_REGISTER    0x04  // [14:8]=slave address, [7:0]=data
#define STATUS_REGISTER   0x08  // READY (bit3), ACKERROR (bit2), BUSY (bit1), DONE (bit0)
#define READ_REGISTER     0x0C  // [7:0]=data out

// Control bits
#define ENABLE_BIT        0x01
#define STOP_BIT          0x02
#define RW_BIT            0x04
#define CONTINUE_BIT      0x08

// Status bits
#define READY_BIT         0x08
#define ACKERROR_BIT      0x04
#define DONE_BIT          0x01

// DS3231 I2C address and register map
#define RTC_ADDRESS       0x68
#define REG_SECONDS       0x00
#define REG_MINUTES       0x01
#define REG_HOURS         0x02
#define REG_WEEKDAY       0x03
#define REG_DAY           0x04
#define REG_MONTH         0x05
#define REG_YEAR          0x06
#define REG_TEMP_HIGH     0x11
#define REG_TEMP_LOW      0x12

// Set the RTC time: second, minute, hour, weekday, day, month, year (BCD)
void set_rtc_time(byte second, byte minute, byte hour,
                  byte week_day, byte day, byte month, byte year);

// Retrieve the RTC time via pointers
void get_rtc_time(byte *second, byte *minute, byte *hour,
                  byte *week_day, byte *day, byte *month, byte *year);

// Read temperature from RTC and return as float
float get_rtc_temp(void);


#endif // RTC_DRIVER_H
