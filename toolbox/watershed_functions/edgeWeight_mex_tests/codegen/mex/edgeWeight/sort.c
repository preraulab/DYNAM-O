/*
 * Academic License - for use in teaching, academic research, and meeting
 * course requirements at degree granting institutions only.  Not for
 * government, commercial, or other organizational use.
 *
 * sort.c
 *
 * Code generation for function 'sort'
 *
 */

/* Include files */
#include "sort.h"
#include "edgeWeight_data.h"
#include "edgeWeight_emxutil.h"
#include "edgeWeight_types.h"
#include "eml_int_forloop_overflow_check.h"
#include "rt_nonfinite.h"
#include "sortIdx.h"

/* Variable Definitions */
static emlrtRSInfo o_emlrtRSI =
    {
        76,     /* lineNo */
        "sort", /* fcnName */
        "/Applications/MATLAB_R2022a.app/toolbox/eml/eml/+coder/+internal/"
        "sort.m" /* pathName */
};

static emlrtRSInfo p_emlrtRSI =
    {
        79,     /* lineNo */
        "sort", /* fcnName */
        "/Applications/MATLAB_R2022a.app/toolbox/eml/eml/+coder/+internal/"
        "sort.m" /* pathName */
};

static emlrtRSInfo q_emlrtRSI =
    {
        81,     /* lineNo */
        "sort", /* fcnName */
        "/Applications/MATLAB_R2022a.app/toolbox/eml/eml/+coder/+internal/"
        "sort.m" /* pathName */
};

static emlrtRSInfo r_emlrtRSI =
    {
        84,     /* lineNo */
        "sort", /* fcnName */
        "/Applications/MATLAB_R2022a.app/toolbox/eml/eml/+coder/+internal/"
        "sort.m" /* pathName */
};

static emlrtRSInfo s_emlrtRSI =
    {
        87,     /* lineNo */
        "sort", /* fcnName */
        "/Applications/MATLAB_R2022a.app/toolbox/eml/eml/+coder/+internal/"
        "sort.m" /* pathName */
};

static emlrtRSInfo t_emlrtRSI =
    {
        90,     /* lineNo */
        "sort", /* fcnName */
        "/Applications/MATLAB_R2022a.app/toolbox/eml/eml/+coder/+internal/"
        "sort.m" /* pathName */
};

static emlrtRTEInfo m_emlrtRTEI =
    {
        56,     /* lineNo */
        24,     /* colNo */
        "sort", /* fName */
        "/Applications/MATLAB_R2022a.app/toolbox/eml/eml/+coder/+internal/"
        "sort.m" /* pName */
};

static emlrtRTEInfo n_emlrtRTEI =
    {
        75,     /* lineNo */
        26,     /* colNo */
        "sort", /* fName */
        "/Applications/MATLAB_R2022a.app/toolbox/eml/eml/+coder/+internal/"
        "sort.m" /* pName */
};

static emlrtRTEInfo o_emlrtRTEI =
    {
        56,     /* lineNo */
        1,      /* colNo */
        "sort", /* fName */
        "/Applications/MATLAB_R2022a.app/toolbox/eml/eml/+coder/+internal/"
        "sort.m" /* pName */
};

static emlrtRTEInfo p_emlrtRTEI =
    {
        1,      /* lineNo */
        20,     /* colNo */
        "sort", /* fName */
        "/Applications/MATLAB_R2022a.app/toolbox/eml/eml/+coder/+internal/"
        "sort.m" /* pName */
};

/* Function Definitions */
void sort(const emlrtStack *sp, emxArray_real_T *x, emxArray_int32_T *idx)
{
  emlrtStack b_st;
  emlrtStack st;
  emxArray_int32_T *iidx;
  emxArray_real_T *vwork;
  real_T *vwork_data;
  real_T *x_data;
  int32_T dim;
  int32_T i;
  int32_T i1;
  int32_T k;
  int32_T vlen;
  int32_T vstride;
  int32_T *idx_data;
  int32_T *iidx_data;
  st.prev = sp;
  st.tls = sp->tls;
  b_st.prev = &st;
  b_st.tls = st.tls;
  x_data = x->data;
  emlrtHeapReferenceStackEnterFcnR2012b((emlrtCTX)sp);
  dim = 0;
  if (x->size[0] != 1) {
    dim = -1;
  }
  emxInit_real_T(sp, &vwork, &o_emlrtRTEI);
  if (dim + 2 <= 1) {
    i = x->size[0];
  } else {
    i = 1;
  }
  vlen = i - 1;
  i1 = vwork->size[0];
  vwork->size[0] = i;
  emxEnsureCapacity_real_T(sp, vwork, i1, &m_emlrtRTEI);
  vwork_data = vwork->data;
  i1 = idx->size[0];
  idx->size[0] = x->size[0];
  emxEnsureCapacity_int32_T(sp, idx, i1, &n_emlrtRTEI);
  idx_data = idx->data;
  st.site = &o_emlrtRSI;
  vstride = 1;
  for (k = 0; k <= dim; k++) {
    vstride *= x->size[0];
  }
  st.site = &p_emlrtRSI;
  st.site = &q_emlrtRSI;
  if (vstride > 2147483646) {
    b_st.site = &j_emlrtRSI;
    check_forloop_overflow_error(&b_st);
  }
  emxInit_int32_T(sp, &iidx, &p_emlrtRTEI);
  for (dim = 0; dim < vstride; dim++) {
    st.site = &r_emlrtRSI;
    if (i > 2147483646) {
      b_st.site = &j_emlrtRSI;
      check_forloop_overflow_error(&b_st);
    }
    for (k = 0; k <= vlen; k++) {
      vwork_data[k] = x_data[dim + k * vstride];
    }
    st.site = &s_emlrtRSI;
    sortIdx(&st, vwork, iidx);
    iidx_data = iidx->data;
    vwork_data = vwork->data;
    st.site = &t_emlrtRSI;
    for (k = 0; k <= vlen; k++) {
      i1 = dim + k * vstride;
      x_data[i1] = vwork_data[k];
      idx_data[i1] = iidx_data[k];
    }
  }
  emxFree_int32_T(sp, &iidx);
  emxFree_real_T(sp, &vwork);
  emlrtHeapReferenceStackLeaveFcnR2012b((emlrtCTX)sp);
}

/* End of code generation (sort.c) */
