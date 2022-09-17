/*
 * Academic License - for use in teaching, academic research, and meeting
 * course requirements at degree granting institutions only.  Not for
 * government, commercial, or other organizational use.
 *
 * edgeWeight.h
 *
 * Code generation for function 'edgeWeight'
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
real32_T edgeWeight(const emlrtStack *sp, const emxArray_real_T *bnds_ii,
                    const emxArray_real_T *rgn_jj,
                    const emxArray_real32_T *data);

emlrtCTX emlrtGetRootTLSGlobal(void);

void emlrtLockerFunction(EmlrtLockeeFunction aLockee, emlrtConstCTX aTLS,
                         void *aData);

/* End of code generation (edgeWeight.h) */
