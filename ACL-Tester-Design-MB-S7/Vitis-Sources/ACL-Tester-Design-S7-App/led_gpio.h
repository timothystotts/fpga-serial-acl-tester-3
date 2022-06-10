/*------------------------------------------------------------------------------
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
 * @file led_gpio.h
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

#ifndef _SRC_LED_GPIO
#define _SRC_LED_GPIO

#include "xil_types.h"

/**-----------------------------------------------------------------------------
 * @brief
 * The number of color LED emitters driven by the gpio driver.
 */
#define N_COLOR_LEDS ((int) 6)

/**-----------------------------------------------------------------------------
 * @brief
 * The number of basic LED emitters driven by the gpio driver.
 */
#define N_BASIC_LEDS ((int) 4)

typedef struct COLOR_LED_TAG {
	u32 gpioChannel; // The channel of the GPIO driver managing color lEDs
	u32 gpioIndex; // The bitmask index for this LED
	char filamentColor;
	u8 silkLedIndex;
} t_color_led_constants;

typedef struct RGB_LED_TAG {
	u8 eanbleRed;
	u8 enableGreen;
	u8 enableBlue;
} t_rgb_led_enable;

typedef struct RGB_LED_SILK_TAG {
	t_rgb_led_enable rgb;
	u8 ledSilk;
} t_rgb_led_enable_silk;

typedef struct BASIC_LED_TAG {
	u32 gpioChannel; // The channel of the GPIO driver maanging basic LEDs
	u32 gpioIndex; // The bitmask index for this LED
	u8 silkLedIndex;
} t_basic_led_constants;

void InitLedsGpio(void);
void InitColorLedsOff(void);
void InitBasicLedsOff(void);
void InitAllLedsOff(void);
int SetColorLedState(const u8 ledSilk, const char color, const bool emitterOn);
int SetBasicLedState(const u8 ledSilk, const bool emitterOn);


#endif // _SRC_LED_GPIO

