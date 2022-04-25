/*
 * Academic License - for use in teaching, academic research, and meeting
 * course requirements at degree granting institutions only.  Not for
 * government, commercial, or other organizational use.
 *
 * sum.h
 *
 * Code generation for function 'sum'
 *
 */

#pragma once

/* Include files */
#include "multitaper_spectrogram_coder_types.h"
#include "rtwtypes.h"
#include "emlrt.h"
#include "mex.h"
#include "omp.h"
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* Function Declarations */
void b_sum(const emlrtStack *sp, const emxArray_real32_T *x, emxArray_real32_T
           *y);
void sum(const emlrtStack *sp, const emxArray_real32_T *x, emxArray_real32_T *y);

/* End of code generation (sum.h) */
