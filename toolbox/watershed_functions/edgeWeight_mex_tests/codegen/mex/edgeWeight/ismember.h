/*
 * Academic License - for use in teaching, academic research, and meeting
 * course requirements at degree granting institutions only.  Not for
 * government, commercial, or other organizational use.
 *
 * ismember.h
 *
 * Code generation for function 'ismember'
 *
 */

#pragma once

/* Include files */
#include "edgeWeight_types.h"
#include "rtwtypes.h"
#include "emlrt.h"
#include "mex.h"
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* Function Declarations */
void isMember(const emlrtStack *sp, const emxArray_real_T *a,
              const emxArray_real_T *s, emxArray_boolean_T *tf);

/* End of code generation (ismember.h) */
