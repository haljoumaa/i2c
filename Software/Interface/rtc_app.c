#include "rtc_driver.h"
#include "rtc_driver.c"


int main(void) {
    byte s,m,h,wd,d,mo,yr;
    float temp;

    set_rtc_time(0,0,12,3,1,1,25);
    get_rtc_time(&s,&m,&h,&wd,&d,&mo,&yr);
    temp = get_rtc_temp();

    printf("Time: %02d:%02d:%02d\n", h,m,s);
    printf("Date: %02d/%02d/20%02d\n", d,mo,yr);
    printf("Temp: %.2f°C\n", temp);
    return 0;
}
