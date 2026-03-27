from ev3dev2.motor import LargeMotor, OUTPUT_B
import time

motorA = LargeMotor(OUTPUT_B)
voltages = [100, 80, 60, 40, 20, -20, -40, -60, -80, -100]

try:
    for vol in voltages:
        timeStart = time.time()
        startPos = motorA.position
        name = "data" + str(vol) + ".txt"
        file = open(name, "w")

        while True:
            timeNow = time.time() - timeStart
            motorA.run_direct(duty_cycle_sp=vol)
            pos = motorA.position - startPos
            file.write(str(timeNow) + " " + str(pos) + " " + str(motorA.speed) + "\n")

            if timeNow > 1:
                motorA.run_direct(duty_cycle_sp=0)
                break

            time.sleep(0.01)


        file.close()
        motorA.stop(stop_action='brake')
        time.sleep(0.4)

except Exception as e:
    raise e

finally:
    motorA.stop(stop_action='brake')
