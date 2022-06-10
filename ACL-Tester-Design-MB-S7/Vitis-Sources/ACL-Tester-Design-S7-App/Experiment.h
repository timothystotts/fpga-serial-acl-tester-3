/**-----------------------------------------------------------------------------
-- MIT License
--
-- Copyright (c) 2020 Timothy Stotts
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
 * @file Experiment.h
 *
 * @brief A SoPC top-level design with the PMOD ACL2 custom driver.
 * This design tests an accelerometer. The readings are displayed on
 * a PMOD CLS 16x2 dot-matrix LCD and printed on a USB-UART display terminal.
 *
 * @author
 * Timothy Stotts (timothystotts08@gmail.com)
 *
 * @copyright
 * (c) 2020 Copyright Timothy Stotts
 *
 * This program is free software; distributed under the terms of the MIT
 * License.
------------------------------------------------------------------------------*/
#ifndef _EXPERIMENT_H_
#define _EXPERIMENT_H_

#include <stdint.h>
#include <stdbool.h>
#include "FreeRTOS.h"
#include "task.h"
#include "queue.h"

#define PRINTF_BUF_SZ 34
#define DELAY_10_SECONDS	10000UL
#define DELAY_1_SECOND		1000UL

enum OPERATING_MODE_TAG {
	OPERATING_MODE_MEAS,
	OPERATING_MODE_LINK,
	OPERATING_MODE_BOOT,
	OPERATING_MODE_NONE
};

#define CNT_START 0
#define CNT_DONE 5
#define CNT_PAST_DONE 6

typedef struct CLS_LINES_TAG {
	char line1[17];
	char line2[17];
} t_cls_lines;

void Experiment_prvAcl2Task( void *pvParameters );

#endif // _EXPERIMENT_H_
