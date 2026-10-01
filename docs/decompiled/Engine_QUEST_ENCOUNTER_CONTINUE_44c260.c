
/* WARNING: Globals starting with '_' overlap smaller symbols at the same address */

void __fastcall Engine_QUEST_ENCOUNTER_CONTINUE_44c260(int param_1)

{
  float10 fVar1;
  
  *(undefined4 *)(param_1 + 0x28) = DAT_0057f484;
  fVar1 = (float10)fpatan((float10)((*(int *)(param_1 + 0x23c) >> 0x10) -
                                   (*(int *)(param_1 + 0x240) >> 0x10)),
                          (float10)((int)(short)*(int *)(param_1 + 0x240) -
                                   (int)(short)*(int *)(param_1 + 0x23c)));
  fVar1 = (float10)_DAT_0051c970 - fVar1;
  *(float *)(param_1 + 4) = (float)fVar1;
  if (fVar1 < (float10)_DAT_005217b0 != (NAN(fVar1) || NAN((float10)_DAT_005217b0))) {
    do {
      *(float *)(param_1 + 4) = *(float *)(param_1 + 4) + _DAT_005217ac;
    } while (*(float *)(param_1 + 4) < _DAT_005217b0 !=
             (NAN(*(float *)(param_1 + 4)) || NAN(_DAT_005217b0)));
  }
  *(undefined1 *)(param_1 + 0x246) = 0;
  return;
}

