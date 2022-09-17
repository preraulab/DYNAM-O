/*
 * Academic License - for use in teaching, academic research, and meeting
 * course requirements at degree granting institutions only.  Not for
 * government, commercial, or other organizational use.
 *
 * edgeWeight.c
 *
 * Code generation for function 'edgeWeight'
 *
 */

/* Include files */
#include "edgeWeight.h"
#include "edgeWeight_data.h"
#include "edgeWeight_emxutil.h"
#include "edgeWeight_types.h"
#include "eml_int_forloop_overflow_check.h"
#include "indexShapeCheck.h"
#include "ismember.h"
#include "rt_nonfinite.h"
#include "mwmathutil.h"
#include "omp.h"

/* Variable Definitions */
static emlrtRSInfo emlrtRSI = {
    17,           /* lineNo */
    "edgeWeight", /* fcnName */
    "/Users/Mike/code/toolboxes/watershed_TFpeaks_dev/toolbox/"
    "watershed_functions/edgeWeight.m" /* pathName */
};

static emlrtRSInfo b_emlrtRSI = {
    26,           /* lineNo */
    "edgeWeight", /* fcnName */
    "/Users/Mike/code/toolboxes/watershed_TFpeaks_dev/toolbox/"
    "watershed_functions/edgeWeight.m" /* pathName */
};

static emlrtRSInfo
    c_emlrtRSI =
        {
            45,         /* lineNo */
            "ismember", /* fcnName */
            "/Applications/MATLAB_R2022a.app/toolbox/eml/lib/matlab/ops/"
            "ismember.m" /* pathName */
};

static emlrtRSInfo pb_emlrtRSI = {
    15,    /* lineNo */
    "max", /* fcnName */
    "/Applications/MATLAB_R2022a.app/toolbox/eml/lib/matlab/datafun/max.m" /* pathName
                                                                            */
};

static emlrtRSInfo qb_emlrtRSI = {
    44,         /* lineNo */
    "minOrMax", /* fcnName */
    "/Applications/MATLAB_R2022a.app/toolbox/eml/eml/+coder/+internal/"
    "minOrMax.m" /* pathName */
};

static emlrtRSInfo rb_emlrtRSI = {
    79,        /* lineNo */
    "maximum", /* fcnName */
    "/Applications/MATLAB_R2022a.app/toolbox/eml/eml/+coder/+internal/"
    "minOrMax.m" /* pathName */
};

static emlrtRSInfo sb_emlrtRSI = {
    191,             /* lineNo */
    "unaryMinOrMax", /* fcnName */
    "/Applications/MATLAB_R2022a.app/toolbox/eml/eml/+coder/+internal/"
    "unaryMinOrMax.m" /* pathName */
};

static emlrtRSInfo tb_emlrtRSI = {
    902,                    /* lineNo */
    "maxRealVectorOmitNaN", /* fcnName */
    "/Applications/MATLAB_R2022a.app/toolbox/eml/eml/+coder/+internal/"
    "unaryMinOrMax.m" /* pathName */
};

static emlrtRSInfo ub_emlrtRSI = {
    72,                      /* lineNo */
    "vectorMinOrMaxInPlace", /* fcnName */
    "/Applications/MATLAB_R2022a.app/toolbox/eml/eml/+coder/+internal/"
    "vectorMinOrMaxInPlace.m" /* pathName */
};

static emlrtRSInfo vb_emlrtRSI = {
    64,                      /* lineNo */
    "vectorMinOrMaxInPlace", /* fcnName */
    "/Applications/MATLAB_R2022a.app/toolbox/eml/eml/+coder/+internal/"
    "vectorMinOrMaxInPlace.m" /* pathName */
};

static emlrtRSInfo wb_emlrtRSI = {
    113,         /* lineNo */
    "findFirst", /* fcnName */
    "/Applications/MATLAB_R2022a.app/toolbox/eml/eml/+coder/+internal/"
    "vectorMinOrMaxInPlace.m" /* pathName */
};

static emlrtRSInfo xb_emlrtRSI = {
    130,                        /* lineNo */
    "minOrMaxRealVectorKernel", /* fcnName */
    "/Applications/MATLAB_R2022a.app/toolbox/eml/eml/+coder/+internal/"
    "vectorMinOrMaxInPlace.m" /* pathName */
};

static emlrtRSInfo yb_emlrtRSI = {
    15,    /* lineNo */
    "min", /* fcnName */
    "/Applications/MATLAB_R2022a.app/toolbox/eml/lib/matlab/datafun/min.m" /* pathName
                                                                            */
};

static emlrtRSInfo ac_emlrtRSI = {
    46,         /* lineNo */
    "minOrMax", /* fcnName */
    "/Applications/MATLAB_R2022a.app/toolbox/eml/eml/+coder/+internal/"
    "minOrMax.m" /* pathName */
};

static emlrtRSInfo bc_emlrtRSI = {
    92,        /* lineNo */
    "minimum", /* fcnName */
    "/Applications/MATLAB_R2022a.app/toolbox/eml/eml/+coder/+internal/"
    "minOrMax.m" /* pathName */
};

static emlrtRSInfo cc_emlrtRSI = {
    209,             /* lineNo */
    "unaryMinOrMax", /* fcnName */
    "/Applications/MATLAB_R2022a.app/toolbox/eml/eml/+coder/+internal/"
    "unaryMinOrMax.m" /* pathName */
};

static emlrtRSInfo dc_emlrtRSI = {
    898,                    /* lineNo */
    "minRealVectorOmitNaN", /* fcnName */
    "/Applications/MATLAB_R2022a.app/toolbox/eml/eml/+coder/+internal/"
    "unaryMinOrMax.m" /* pathName */
};

static emlrtRTEInfo b_emlrtRTEI = {
    135,             /* lineNo */
    27,              /* colNo */
    "unaryMinOrMax", /* fName */
    "/Applications/MATLAB_R2022a.app/toolbox/eml/eml/+coder/+internal/"
    "unaryMinOrMax.m" /* pName */
};

static emlrtBCInfo emlrtBCI = {
    -1,           /* iFirst */
    -1,           /* iLast */
    17,           /* lineNo */
    19,           /* colNo */
    "bnds_ii",    /* aName */
    "edgeWeight", /* fName */
    "/Users/Mike/code/toolboxes/watershed_TFpeaks_dev/toolbox/"
    "watershed_functions/edgeWeight.m", /* pName */
    0                                   /* checkKind */
};

static emlrtDCInfo emlrtDCI = {
    26,           /* lineNo */
    16,           /* colNo */
    "edgeWeight", /* fName */
    "/Users/Mike/code/toolboxes/watershed_TFpeaks_dev/toolbox/"
    "watershed_functions/edgeWeight.m", /* pName */
    1                                   /* checkKind */
};

static emlrtBCInfo b_emlrtBCI = {
    -1,           /* iFirst */
    -1,           /* iLast */
    26,           /* lineNo */
    16,           /* colNo */
    "data",       /* aName */
    "edgeWeight", /* fName */
    "/Users/Mike/code/toolboxes/watershed_TFpeaks_dev/toolbox/"
    "watershed_functions/edgeWeight.m", /* pName */
    0                                   /* checkKind */
};

static emlrtDCInfo b_emlrtDCI = {
    26,           /* lineNo */
    37,           /* colNo */
    "edgeWeight", /* fName */
    "/Users/Mike/code/toolboxes/watershed_TFpeaks_dev/toolbox/"
    "watershed_functions/edgeWeight.m", /* pName */
    1                                   /* checkKind */
};

static emlrtBCInfo c_emlrtBCI = {
    -1,           /* iFirst */
    -1,           /* iLast */
    26,           /* lineNo */
    37,           /* colNo */
    "data",       /* aName */
    "edgeWeight", /* fName */
    "/Users/Mike/code/toolboxes/watershed_TFpeaks_dev/toolbox/"
    "watershed_functions/edgeWeight.m", /* pName */
    0                                   /* checkKind */
};

static emlrtDCInfo c_emlrtDCI = {
    26,           /* lineNo */
    58,           /* colNo */
    "edgeWeight", /* fName */
    "/Users/Mike/code/toolboxes/watershed_TFpeaks_dev/toolbox/"
    "watershed_functions/edgeWeight.m", /* pName */
    1                                   /* checkKind */
};

static emlrtBCInfo d_emlrtBCI = {
    -1,           /* iFirst */
    -1,           /* iLast */
    26,           /* lineNo */
    58,           /* colNo */
    "data",       /* aName */
    "edgeWeight", /* fName */
    "/Users/Mike/code/toolboxes/watershed_TFpeaks_dev/toolbox/"
    "watershed_functions/edgeWeight.m", /* pName */
    0                                   /* checkKind */
};

static emlrtRTEInfo e_emlrtRTEI = {
    1,            /* lineNo */
    14,           /* colNo */
    "edgeWeight", /* fName */
    "/Users/Mike/code/toolboxes/watershed_TFpeaks_dev/toolbox/"
    "watershed_functions/edgeWeight.m" /* pName */
};

static emlrtRTEInfo f_emlrtRTEI = {
    17,           /* lineNo */
    1,            /* colNo */
    "edgeWeight", /* fName */
    "/Users/Mike/code/toolboxes/watershed_TFpeaks_dev/toolbox/"
    "watershed_functions/edgeWeight.m" /* pName */
};

static emlrtRTEInfo g_emlrtRTEI = {
    17,           /* lineNo */
    19,           /* colNo */
    "edgeWeight", /* fName */
    "/Users/Mike/code/toolboxes/watershed_TFpeaks_dev/toolbox/"
    "watershed_functions/edgeWeight.m" /* pName */
};

/* Function Definitions */
real32_T edgeWeight(const emlrtStack *sp, const emxArray_real_T *bnds_ii,
                    const emxArray_real_T *rgn_jj,
                    const emxArray_real32_T *data)
{
  emlrtStack b_st;
  emlrtStack c_st;
  emlrtStack d_st;
  emlrtStack e_st;
  emlrtStack f_st;
  emlrtStack g_st;
  emlrtStack h_st;
  emlrtStack i_st;
  emlrtStack st;
  emxArray_boolean_T *r;
  emxArray_real_T *adj_bnd;
  const real_T *bnds_ii_data;
  const real_T *rgn_jj_data;
  real_T *adj_bnd_data;
  int32_T end;
  int32_T i;
  int32_T idx;
  int32_T k;
  int32_T last;
  const real32_T *data_data;
  real32_T b_ex;
  real32_T c_ex;
  real32_T e;
  real32_T ex;
  boolean_T exitg1;
  boolean_T *r1;
  st.prev = sp;
  st.tls = sp->tls;
  b_st.prev = &st;
  b_st.tls = st.tls;
  c_st.prev = &b_st;
  c_st.tls = b_st.tls;
  d_st.prev = &c_st;
  d_st.tls = c_st.tls;
  e_st.prev = &d_st;
  e_st.tls = d_st.tls;
  f_st.prev = &e_st;
  f_st.tls = e_st.tls;
  g_st.prev = &f_st;
  g_st.tls = f_st.tls;
  h_st.prev = &g_st;
  h_st.tls = g_st.tls;
  i_st.prev = &h_st;
  i_st.tls = h_st.tls;
  data_data = data->data;
  rgn_jj_data = rgn_jj->data;
  bnds_ii_data = bnds_ii->data;
  emlrtHeapReferenceStackEnterFcnR2012b((emlrtCTX)sp);
  emxInit_boolean_T(sp, &r, &g_emlrtRTEI);
  /*  edgeWeight computes the directed edge weight from region jj to region ii.
   */
  /*  The weight is (the difference between the maximum of the adjacency
   * boundary  */
  /*  and the minimum of the ii boundary) minus (the difference between the */
  /*  maximum of the jj region and the maximum of the adjacency boundary). */
  /*  */
  /*  INPUTS: */
  /*    merge_rule -- */
  /*    bnds_ii -- vector of linear indices of boundary of "to region" */
  /*    rgn_jj  -- vector of linear indices of pixels of "from region" */
  /*    data    -- 2D image data from which regions were defined */
  /*  */
  /*  OUTPUTS: */
  /*    e       -- edge weight */
  /*  fastest version to get intersection of "to region" boundary with "from
   * region"  */
  st.site = &emlrtRSI;
  b_st.site = &c_emlrtRSI;
  isMember(&b_st, bnds_ii, rgn_jj, r);
  r1 = r->data;
  end = r->size[0] - 1;
  idx = 0;
  for (last = 0; last <= end; last++) {
    if (r1[last]) {
      idx++;
    }
  }
  emxInit_real_T(sp, &adj_bnd, &f_emlrtRTEI);
  i = adj_bnd->size[0];
  adj_bnd->size[0] = idx;
  emxEnsureCapacity_real_T(sp, adj_bnd, i, &e_emlrtRTEI);
  adj_bnd_data = adj_bnd->data;
  idx = 0;
  for (last = 0; last <= end; last++) {
    if (r1[last]) {
      if (last + 1 > bnds_ii->size[0]) {
        emlrtDynamicBoundsCheckR2012b(last + 1, 1, bnds_ii->size[0], &emlrtBCI,
                                      (emlrtCTX)sp);
      }
      adj_bnd_data[idx] = bnds_ii_data[last];
      idx++;
    }
  }
  emxFree_boolean_T(sp, &r);
  /* Add switch case to add new merge rules */
  /*  switch merge_rule */
  /*      case 'default' */
  /*  c = max(data(adj_bnd)) - min(data(bnds_ii)); */
  /*  d = max(data(rgn_jj)) - max(data(adj_bnd)); */
  /*  e = c - d; */
  st.site = &b_emlrtRSI;
  indexShapeCheck(&st, *(int32_T(*)[2])data->size, adj_bnd->size[0]);
  st.site = &b_emlrtRSI;
  indexShapeCheck(&st, *(int32_T(*)[2])data->size, bnds_ii->size[0]);
  st.site = &b_emlrtRSI;
  indexShapeCheck(&st, *(int32_T(*)[2])data->size, rgn_jj->size[0]);
  st.site = &b_emlrtRSI;
  idx = data->size[0] * data->size[1];
  end = adj_bnd->size[0];
  for (i = 0; i < end; i++) {
    if (adj_bnd_data[i] != (int32_T)muDoubleScalarFloor(adj_bnd_data[i])) {
      emlrtIntegerCheckR2012b(adj_bnd_data[i], &emlrtDCI, &st);
    }
    last = (int32_T)adj_bnd_data[i];
    if ((last < 1) || (last > idx)) {
      emlrtDynamicBoundsCheckR2012b(last, 1, idx, &b_emlrtBCI, &st);
    }
  }
  b_st.site = &pb_emlrtRSI;
  c_st.site = &qb_emlrtRSI;
  d_st.site = &rb_emlrtRSI;
  if (adj_bnd->size[0] < 1) {
    emlrtErrorWithMessageIdR2018a(&d_st, &b_emlrtRTEI,
                                  "Coder:toolbox:eml_min_or_max_varDimZero",
                                  "Coder:toolbox:eml_min_or_max_varDimZero", 0);
  }
  e_st.site = &sb_emlrtRSI;
  f_st.site = &tb_emlrtRSI;
  last = adj_bnd->size[0];
  if (adj_bnd->size[0] <= 2) {
    if (adj_bnd->size[0] == 1) {
      ex = data_data[(int32_T)adj_bnd_data[0] - 1];
    } else if ((data_data[(int32_T)adj_bnd_data[0] - 1] <
                data_data[(int32_T)adj_bnd_data[1] - 1]) ||
               (muSingleScalarIsNaN(data_data[(int32_T)adj_bnd_data[0] - 1]) &&
                (!muSingleScalarIsNaN(
                    data_data[(int32_T)adj_bnd_data[1] - 1])))) {
      ex = data_data[(int32_T)adj_bnd_data[1] - 1];
    } else {
      ex = data_data[(int32_T)adj_bnd_data[0] - 1];
    }
  } else {
    g_st.site = &vb_emlrtRSI;
    if (!muSingleScalarIsNaN(data_data[(int32_T)adj_bnd_data[0] - 1])) {
      idx = 1;
    } else {
      idx = 0;
      h_st.site = &wb_emlrtRSI;
      if (adj_bnd->size[0] > 2147483646) {
        i_st.site = &j_emlrtRSI;
        check_forloop_overflow_error(&i_st);
      }
      k = 2;
      exitg1 = false;
      while ((!exitg1) && (k <= last)) {
        if (!muSingleScalarIsNaN(data_data[(int32_T)adj_bnd_data[k - 1] - 1])) {
          idx = k;
          exitg1 = true;
        } else {
          k++;
        }
      }
    }
    if (idx == 0) {
      ex = data_data[(int32_T)adj_bnd_data[0] - 1];
    } else {
      g_st.site = &ub_emlrtRSI;
      ex = data_data[(int32_T)adj_bnd_data[idx - 1] - 1];
      end = idx + 1;
      h_st.site = &xb_emlrtRSI;
      if ((idx + 1 <= adj_bnd->size[0]) && (adj_bnd->size[0] > 2147483646)) {
        i_st.site = &j_emlrtRSI;
        check_forloop_overflow_error(&i_st);
      }
      for (k = end; k <= last; k++) {
        i = (int32_T)adj_bnd_data[k - 1] - 1;
        if (ex < data_data[i]) {
          ex = data_data[i];
        }
      }
    }
  }
  emxFree_real_T(&f_st, &adj_bnd);
  st.site = &b_emlrtRSI;
  idx = data->size[0] * data->size[1];
  end = bnds_ii->size[0];
  for (i = 0; i < end; i++) {
    if (bnds_ii_data[i] != (int32_T)muDoubleScalarFloor(bnds_ii_data[i])) {
      emlrtIntegerCheckR2012b(bnds_ii_data[i], &b_emlrtDCI, &st);
    }
    last = (int32_T)bnds_ii_data[i];
    if ((last < 1) || (last > idx)) {
      emlrtDynamicBoundsCheckR2012b(last, 1, idx, &c_emlrtBCI, &st);
    }
  }
  b_st.site = &yb_emlrtRSI;
  c_st.site = &ac_emlrtRSI;
  d_st.site = &bc_emlrtRSI;
  if (bnds_ii->size[0] < 1) {
    emlrtErrorWithMessageIdR2018a(&d_st, &b_emlrtRTEI,
                                  "Coder:toolbox:eml_min_or_max_varDimZero",
                                  "Coder:toolbox:eml_min_or_max_varDimZero", 0);
  }
  e_st.site = &cc_emlrtRSI;
  f_st.site = &dc_emlrtRSI;
  last = bnds_ii->size[0];
  if (bnds_ii->size[0] <= 2) {
    if (bnds_ii->size[0] == 1) {
      b_ex = data_data[(int32_T)bnds_ii_data[0] - 1];
    } else if ((data_data[(int32_T)bnds_ii_data[0] - 1] >
                data_data[(int32_T)bnds_ii_data[1] - 1]) ||
               (muSingleScalarIsNaN(data_data[(int32_T)bnds_ii_data[0] - 1]) &&
                (!muSingleScalarIsNaN(
                    data_data[(int32_T)bnds_ii_data[1] - 1])))) {
      b_ex = data_data[(int32_T)bnds_ii_data[1] - 1];
    } else {
      b_ex = data_data[(int32_T)bnds_ii_data[0] - 1];
    }
  } else {
    g_st.site = &vb_emlrtRSI;
    if (!muSingleScalarIsNaN(data_data[(int32_T)bnds_ii_data[0] - 1])) {
      idx = 1;
    } else {
      idx = 0;
      h_st.site = &wb_emlrtRSI;
      if (bnds_ii->size[0] > 2147483646) {
        i_st.site = &j_emlrtRSI;
        check_forloop_overflow_error(&i_st);
      }
      k = 2;
      exitg1 = false;
      while ((!exitg1) && (k <= last)) {
        if (!muSingleScalarIsNaN(data_data[(int32_T)bnds_ii_data[k - 1] - 1])) {
          idx = k;
          exitg1 = true;
        } else {
          k++;
        }
      }
    }
    if (idx == 0) {
      b_ex = data_data[(int32_T)bnds_ii_data[0] - 1];
    } else {
      g_st.site = &ub_emlrtRSI;
      b_ex = data_data[(int32_T)bnds_ii_data[idx - 1] - 1];
      end = idx + 1;
      h_st.site = &xb_emlrtRSI;
      if ((idx + 1 <= bnds_ii->size[0]) && (bnds_ii->size[0] > 2147483646)) {
        i_st.site = &j_emlrtRSI;
        check_forloop_overflow_error(&i_st);
      }
      for (k = end; k <= last; k++) {
        i = (int32_T)bnds_ii_data[k - 1] - 1;
        if (b_ex > data_data[i]) {
          b_ex = data_data[i];
        }
      }
    }
  }
  st.site = &b_emlrtRSI;
  idx = data->size[0] * data->size[1];
  end = rgn_jj->size[0];
  for (i = 0; i < end; i++) {
    if (rgn_jj_data[i] != (int32_T)muDoubleScalarFloor(rgn_jj_data[i])) {
      emlrtIntegerCheckR2012b(rgn_jj_data[i], &c_emlrtDCI, &st);
    }
    last = (int32_T)rgn_jj_data[i];
    if ((last < 1) || (last > idx)) {
      emlrtDynamicBoundsCheckR2012b(last, 1, idx, &d_emlrtBCI, &st);
    }
  }
  b_st.site = &pb_emlrtRSI;
  c_st.site = &qb_emlrtRSI;
  d_st.site = &rb_emlrtRSI;
  if (rgn_jj->size[0] < 1) {
    emlrtErrorWithMessageIdR2018a(&d_st, &b_emlrtRTEI,
                                  "Coder:toolbox:eml_min_or_max_varDimZero",
                                  "Coder:toolbox:eml_min_or_max_varDimZero", 0);
  }
  e_st.site = &sb_emlrtRSI;
  f_st.site = &tb_emlrtRSI;
  last = rgn_jj->size[0];
  if (rgn_jj->size[0] <= 2) {
    if (rgn_jj->size[0] == 1) {
      c_ex = data_data[(int32_T)rgn_jj_data[0] - 1];
    } else if ((data_data[(int32_T)rgn_jj_data[0] - 1] <
                data_data[(int32_T)rgn_jj_data[1] - 1]) ||
               (muSingleScalarIsNaN(data_data[(int32_T)rgn_jj_data[0] - 1]) &&
                (!muSingleScalarIsNaN(
                    data_data[(int32_T)rgn_jj_data[1] - 1])))) {
      c_ex = data_data[(int32_T)rgn_jj_data[1] - 1];
    } else {
      c_ex = data_data[(int32_T)rgn_jj_data[0] - 1];
    }
  } else {
    g_st.site = &vb_emlrtRSI;
    if (!muSingleScalarIsNaN(data_data[(int32_T)rgn_jj_data[0] - 1])) {
      idx = 1;
    } else {
      idx = 0;
      h_st.site = &wb_emlrtRSI;
      if (rgn_jj->size[0] > 2147483646) {
        i_st.site = &j_emlrtRSI;
        check_forloop_overflow_error(&i_st);
      }
      k = 2;
      exitg1 = false;
      while ((!exitg1) && (k <= last)) {
        if (!muSingleScalarIsNaN(data_data[(int32_T)rgn_jj_data[k - 1] - 1])) {
          idx = k;
          exitg1 = true;
        } else {
          k++;
        }
      }
    }
    if (idx == 0) {
      c_ex = data_data[(int32_T)rgn_jj_data[0] - 1];
    } else {
      g_st.site = &ub_emlrtRSI;
      c_ex = data_data[(int32_T)rgn_jj_data[idx - 1] - 1];
      end = idx + 1;
      h_st.site = &xb_emlrtRSI;
      if ((idx + 1 <= rgn_jj->size[0]) && (rgn_jj->size[0] > 2147483646)) {
        i_st.site = &j_emlrtRSI;
        check_forloop_overflow_error(&i_st);
      }
      for (k = end; k <= last; k++) {
        i = (int32_T)rgn_jj_data[k - 1] - 1;
        if (c_ex < data_data[i]) {
          c_ex = data_data[i];
        }
      }
    }
  }
  e = (2.0F * ex - b_ex) - c_ex;
  /*  equivalent to above lines */
  emlrtHeapReferenceStackLeaveFcnR2012b((emlrtCTX)sp);
  return e;
}

emlrtCTX emlrtGetRootTLSGlobal(void)
{
  return emlrtRootTLSGlobal;
}

void emlrtLockerFunction(EmlrtLockeeFunction aLockee, emlrtConstCTX aTLS,
                         void *aData)
{
  omp_set_lock(&emlrtLockGlobal);
  emlrtCallLockeeFunction(aLockee, aTLS, aData);
  omp_unset_lock(&emlrtLockGlobal);
}

/* End of code generation (edgeWeight.c) */
