
undefined4 __thiscall
FUN_004c9950(int param_1,short param_2,wchar_t *param_3,undefined4 param_4,undefined4 param_5,
            byte param_6,short param_7,short param_8,short param_9,int param_10)

{
  undefined1 *puVar1;
  short sVar2;
  wchar_t *_Str;
  int iVar3;
  short sVar4;
  size_t sVar5;
  int iVar6;
  int iVar7;
  int local_4;
  
  sVar2 = param_2;
  if (param_2 < 0) {
    return 0xffffffff;
  }
  _param_2 = (int)param_2;
  local_4 = param_1;
  FUN_004c88f0(&local_4,&param_2);
  iVar6 = local_4;
  if ((local_4 != *(int *)(param_1 + 4)) && (local_4 != -0x10)) {
    sVar4 = *(short *)(param_1 + 0x1c);
    if (99 < sVar4) {
      FUN_004c91a0();
      sVar4 = *(short *)(param_1 + 0x1c);
      if (99 < sVar4) {
        return 0xffffffff;
      }
    }
    _Str = param_3;
    *(short *)(sVar4 * 0x314 + 0x220 + param_1) = sVar2;
    *(undefined4 *)(*(short *)(param_1 + 0x1c) * 0x314 + 0x224 + param_1) = param_4;
    *(undefined4 *)(*(short *)(param_1 + 0x1c) * 0x314 + 0x228 + param_1) = param_5;
    *(char *)(*(short *)(param_1 + 0x1c) * 0x314 + 0x22c + param_1) =
         (char)(((uint)*(byte *)(iVar6 + 0x2b) * (uint)param_6) / 0xff);
    sVar5 = wcslen(param_3);
    if (sVar5 < 0x100) {
      sVar5 = wcslen(_Str);
    }
    else {
      sVar5 = 0xff;
    }
    wcsncpy((wchar_t *)(*(short *)(param_1 + 0x1c) * 0x314 + 0x20 + param_1),_Str,sVar5);
    iVar3 = param_10;
    *(undefined2 *)(param_1 + 0x20 + (*(short *)(param_1 + 0x1c) * 0x18a + sVar5) * 2) = 0;
    if (param_7 == -1) {
      *(undefined1 *)(*(short *)(param_1 + 0x1c) * 0x314 + 0x22d + param_1) =
           *(undefined1 *)(iVar6 + 0x28);
    }
    else {
      *(char *)(*(short *)(param_1 + 0x1c) * 0x314 + 0x22d + param_1) = (char)param_7;
    }
    if (param_8 == -1) {
      *(undefined1 *)(*(short *)(param_1 + 0x1c) * 0x314 + 0x22e + param_1) =
           *(undefined1 *)(iVar6 + 0x29);
    }
    else {
      *(char *)(*(short *)(param_1 + 0x1c) * 0x314 + 0x22e + param_1) = (char)param_8;
    }
    if (param_9 == -1) {
      *(undefined1 *)(*(short *)(param_1 + 0x1c) * 0x314 + 0x22f + param_1) =
           *(undefined1 *)(iVar6 + 0x2a);
    }
    else {
      *(char *)(*(short *)(param_1 + 0x1c) * 0x314 + 0x22f + param_1) = (char)param_9;
    }
    if (param_10 == 0) {
      *(undefined1 *)(*(short *)(param_1 + 0x1c) * 0x314 + 0x230 + param_1) = 0;
    }
    else {
      sVar5 = wcslen(_Str);
      iVar6 = 0;
      *(undefined1 *)(*(short *)(param_1 + 0x1c) * 0x314 + 0x230 + param_1) = 1;
      if (0 < (int)sVar5) {
        do {
          puVar1 = (undefined1 *)(iVar6 + iVar3);
          iVar7 = *(short *)(param_1 + 0x1c) * 0x314 + iVar6;
          iVar6 = iVar6 + 1;
          *(undefined1 *)(iVar7 + 0x231 + param_1) = *puVar1;
        } while (iVar6 < (int)sVar5);
        *(short *)(param_1 + 0x1c) = *(short *)(param_1 + 0x1c) + 1;
        return 0;
      }
    }
    *(short *)(param_1 + 0x1c) = *(short *)(param_1 + 0x1c) + 1;
    return 0;
  }
  return 0xffffffff;
}

