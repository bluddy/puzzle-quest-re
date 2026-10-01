
/* WARNING: Globals starting with '_' overlap smaller symbols at the same address */

void __fastcall Engine_QUEST_ENCOUNTER_TURNBACK_44c170(int param_1)

{
  float fVar1;
  int iVar2;
  int iVar3;
  int iVar4;
  float10 fVar5;
  
  iVar2 = *(int *)(param_1 + 0x14);
  if ((iVar2 != 0) || (*(int *)(param_1 + 0x18) != 0)) {
    *(float *)(param_1 + 0x234) = _DAT_005217b4 - *(float *)(param_1 + 0x234);
    *(bool *)(param_1 + 0x245) = *(char *)(param_1 + 0x245) == '\0';
    iVar3 = *(int *)(param_1 + 0x240);
    *(int *)(param_1 + 0xc) = iVar2;
    *(undefined4 *)(param_1 + 0x10) = *(undefined4 *)(param_1 + 0x18);
    *(undefined4 *)(param_1 + 0x28) = DAT_0057f484;
    iVar4 = *(int *)(param_1 + 0x23c);
    *(int *)(param_1 + 0x240) = iVar4;
    *(int *)(param_1 + 0x23c) = iVar3;
    fVar5 = (float10)fpatan((float10)((iVar3 >> 0x10) - (iVar4 >> 0x10)),
                            (float10)((int)(short)iVar4 - (int)(short)iVar3));
    fVar5 = (float10)_DAT_0051c970 - fVar5;
    *(float *)(param_1 + 4) = (float)fVar5;
    if (fVar5 < (float10)_DAT_005217b0 != (NAN(fVar5) || NAN((float10)_DAT_005217b0))) {
      fVar1 = *(float *)(param_1 + 4);
      do {
        fVar1 = fVar1 + _DAT_005217ac;
      } while (fVar1 < _DAT_005217b0 != (NAN(fVar1) || NAN(_DAT_005217b0)));
      *(float *)(param_1 + 4) = fVar1;
    }
    *(undefined4 *)(param_1 + 0xc) = *(undefined4 *)(param_1 + 0x18);
    *(int *)(param_1 + 0x10) = iVar2;
    *(int *)(param_1 + 0x22c) = *(int *)(param_1 + 0x230) + 1;
    *(undefined1 *)(param_1 + 0x246) = 0;
  }
  return;
}

