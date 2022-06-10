/**-----------------------------------------------------------------------------
-- MIT License
--
-- Copyright (c) 2022 Timothy Stotts
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in
-- all copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
-- SOFTWARE.
------------------------------------------------------------------------------*/
/**-----------------------------------------------------------------------------
 * @file led_gpio.c
 *
 * @brief A simple driver to control the states of both color and basic LEDs
 * via GPIO pins that causes either 0% or 100% brightness. No PWM is used.
 *
 * @author
 * Timothy Stotts (timothystotts08@gmail.com)
 *
 * @copyright
 * (c) 2022 Copyright Timothy Stotts
 *
 * This program is free software; distributed under the terms of the MIT
 * License.
------------------------------------------------------------------------------*/

/* FreeRTOS includes. */
#include "FreeRTOS.h"
#include "task.h"
/* Other includes. */
#include <stdbool.h>
#include "led_gpio.h"
#include "xparameters.h"
#include "xgpio.h"

#define LEDIO_DEVICE_ID 1
#define RGBLEDS_SW_CHANNEL 1
#define BASICLEDS_SW_CHANNEL 2
#define RGBLEDS_SWS_MASK 0x00
#define BASICLEDS_SWS_MASK 0x0

/**-----------------------------------------------------------------------------
 * @brief
 * The GPIO index and channel block for color LEDS is assign for each color
 * filament of the two color LEDs of the Arty S7 board.
 */
static const t_color_led_constants c_color_leds[N_COLOR_LEDS] = {
		{1, 0, 'r', 0},
		{1, 1, 'g', 0},
		{1, 2, 'b', 0},
		{1, 3, 'r', 1},
		{1, 4, 'g', 1},
		{1, 5, 'b', 1}
};

/**-----------------------------------------------------------------------------
 * @brief
 * The GPIO index and channel block for basic LEDS is assign for each basic
 * emitter of the four basic LEDs of the Arty S7 board.
 */
static const t_basic_led_constants c_basic_leds[N_BASIC_LEDS] = {
		{2, 0, 2},
		{2, 1, 3},
		{2, 2, 4},
		{2, 3, 5}
};

/**-----------------------------------------------------------------------------
 * @brief
 * The GPIO device representation for the GPIO device driver.
 */
static XGpio ledsGpio;

/**-----------------------------------------------------------------------------
 * @brief
 * Initialize the GPIO device driver for the LEDs.
 */
void InitLedsGpio(void)
{
	/* Initialize the GPIO device for outputting RGB LED emitters R0,G0,B0,R1,G1,B1,
	 * and basic LED emitters L0,L1,L2,L3.
	 * This corresponds to the two channels set in the index one AXI GPIO driver of
	 * the FPGA system block design. */
	taskENTER_CRITICAL();
	XGpio_Initialize(&ledsGpio, LEDIO_DEVICE_ID);
	XGpio_SelfTest(&ledsGpio);
	XGpio_SetDataDirection(&ledsGpio, RGBLEDS_SW_CHANNEL, RGBLEDS_SWS_MASK);
	XGpio_SetDataDirection(&ledsGpio, BASICLEDS_SW_CHANNEL, BASICLEDS_SWS_MASK);
	taskEXIT_CRITICAL();
}

/**-----------------------------------------------------------------------------
 * @brief
 * Initializes the Color LED emitters to an OFF state.
 */
void InitColorLedsOff(void) {
	u32 mask= 0x00000000UL;

	for (int i = 0; i < N_COLOR_LEDS; ++i)
	{
		mask = XGpio_DiscreteRead(&ledsGpio, c_color_leds[i].gpioChannel);
		mask &= ~(1UL << c_color_leds[i].gpioIndex);
		XGpio_DiscreteWrite(&ledsGpio, c_color_leds[i].gpioChannel, mask);
	}
}

/**-----------------------------------------------------------------------------
 * @brief
 * Initializes the Basic LED emitters to an OFF state.
 */
void InitBasicLedsOff(void) {
	u32 mask= 0x00000000UL;

	for (int i = 0; i < N_BASIC_LEDS; ++i)
	{
		mask = XGpio_DiscreteRead(&ledsGpio, c_basic_leds[i].gpioChannel);
		mask &= ~(1UL << c_basic_leds[i].gpioIndex);
		XGpio_DiscreteWrite(&ledsGpio, c_basic_leds[i].gpioChannel, mask);
	}
}

/**-----------------------------------------------------------------------------
 * @brief
 * Turn OFF the color LEDs with initial preset, and then turn off the Basic LEDs
 * with initial preset.
 */
void InitAllLedsOff(void) {
	InitColorLedsOff();
	InitBasicLedsOff();
}

/**-----------------------------------------------------------------------------
 * @brief
 * Set a color LED filament to a percentage of the constant maximum duty cycle
 * strength, which is a major fraction of the PWM period value.
 *
 * @param ledSilk the board silkscreen index of the LED component
 * @param color the RGB filament within the color LED expressed as 'r', 'g', 'b'
 * @param percentFixPt a fixed-point integer of the percentage of strength
 *                     expressed as increments of 0.1%. The value 100 is 10.0%.
 *
 * @return zero for success at finding the filament to adjust, non-zero
 *         otherwise
 */
int SetColorLedState(const u8 ledSilk, const char color, const bool emitterOn) {
	int i = 0;
	int ret = 1; // Failure
	u32 mask = 0x00000000UL;

	for (i = 0; (i < N_COLOR_LEDS) && ret; ++i) {
		const t_color_led_constants* p = &c_color_leds[i];
		if (p->silkLedIndex == ledSilk) {
			if (p->filamentColor == color) {
				mask = XGpio_DiscreteRead(&ledsGpio, p->gpioChannel);
				if (emitterOn)
					mask |= (1UL << p->gpioIndex);
				else
					mask &= ~(1UL << p->gpioIndex);
				XGpio_DiscreteWrite(&ledsGpio, p->gpioChannel, mask);
				ret = 0; // Success
			}
		}
	}

	return ret;
}

/**-----------------------------------------------------------------------------
 * @brief
 * Set a basic LED filament to a percentage of the constant maximum duty cycle
 * strength, which is a major fraction of the PWM period value.
 *
 * @param ledSilk the board silkscreen index of the LED component
 * @param percentFixPt a fixed-point integer of the percentage of strength
 *                     expressed as increments of 0.1%. The value 100 is 10.0%.
 *
 * @return zero for success at finding the filament to adjust, non-zero
 *         otherwise
 */
int SetBasicLedState(const u8 ledSilk, const bool emitterOn) {
	int i = 0;
	int ret = 1; // Failure
	u32 mask = 0x00000000UL;

	for (i = 0; (i < N_BASIC_LEDS) && ret; ++i) {
		const t_basic_led_constants* p = &c_basic_leds[i];
		if (p->silkLedIndex == ledSilk) {
			mask = XGpio_DiscreteRead(&ledsGpio, p->gpioChannel);
			if (emitterOn)
				mask |= (1UL << p->gpioIndex);
			else
				mask &= ~(1UL << p->gpioIndex);
			XGpio_DiscreteWrite(&ledsGpio, p->gpioChannel, mask);
			ret = 0; // Success
		}
	}

	return ret;
}
