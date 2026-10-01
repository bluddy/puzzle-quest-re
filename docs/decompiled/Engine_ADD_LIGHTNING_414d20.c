
void __thiscall
Engine_ADD_LIGHTNING_414d20
          (int param_1,undefined4 param_2,int param_3,int param_4,int param_5,int param_6,
          int param_7)

{
  undefined2 uVar1;
  short *psVar2;
  short sVar3;
  short *psVar4;
  int iVar5;
  int iVar6;
  uint uVar7;
  undefined2 *puVar8;
  int iVar9;
  uint uVar10;
  uint local_2b4;
  int local_2ac;
  int local_2a8;
  int local_2a4;
  undefined4 local_2a0;
  short local_29c [48];
  undefined1 local_23c [12];
  undefined4 local_230;
  int local_22c;
  int local_228;
  int local_224;
  int local_220;
  int local_21c;
  int local_218;
  int local_214;
  undefined4 local_210;
  short local_20c [240];
  uint local_2c [6];
  int local_14;
  undefined1 local_10;
  void *local_c;
  undefined1 *puStack_8;
  undefined4 local_4;
  
  local_4 = 0xffffffff;
  puStack_8 = &LAB_0051015b;
  local_c = ExceptionList;
  if (*(char *)(param_1 + 0x1e) != '\0') {
    ExceptionList = &local_c;
    local_2a0 = param_1;
    FUN_004bdb30();
    psVar4 = local_20c;
    iVar5 = 0x78;
    do {
      *psVar4 = -1;
      psVar4[1] = -1;
      psVar4 = psVar4 + 2;
      iVar5 = iVar5 + -1;
    } while (iVar5 != 0);
    local_214 = DAT_0057f484;
    local_210 = DAT_0057f484 + param_7;
    iVar5 = 0;
    local_224 = param_5;
    local_4 = 0;
    local_230 = param_2;
    local_22c = param_3;
    local_228 = param_4;
    local_220 = param_6;
    local_21c = param_3;
    local_218 = param_4;
    switch(param_2) {
    case 0:
      FUN_004be780(L"MessageRed");
      break;
    case 1:
      FUN_004be780(L"MessageYellow");
      break;
    case 2:
      FUN_004be780(L"MessageGreen");
      break;
    case 3:
      FUN_004be780(L"MessageCyan");
      break;
    case 4:
      FUN_004be780(L"MessagePurple");
      break;
    case 5:
      FUN_004be780(L"MessageOrange");
      break;
    case 6:
      FUN_004be780(L"Lightning");
      uVar7 = local_22c - local_224 >> 0x1f;
      uVar7 = (int)((local_22c - local_224 ^ uVar7) - uVar7) / 0x32;
      uVar10 = 0x18;
      if ((int)uVar7 < 0x19) {
        uVar10 = uVar7;
      }
      uVar7 = local_228 - local_220 >> 0x1f;
      local_2b4 = (int)((local_228 - local_220 ^ uVar7) - uVar7) / 0x32;
      if (0x18 < (int)local_2b4) {
        local_2b4 = 0x18;
      }
      if ((int)local_2b4 < (int)uVar10) {
        local_2b4 = uVar10;
      }
      if ((int)local_2b4 < 3) {
        local_2b4 = 3;
      }
      FUN_00401160(local_29c,4,0x18,&LAB_00402a10);
      iVar6 = 0;
      if (0 < (int)local_2b4) {
        iVar9 = 0;
        do {
          local_29c[iVar6 * 2] = (short)(iVar9 / (int)(local_2b4 - 1)) + (short)param_3;
          local_29c[iVar6 * 2 + 1] = (short)(iVar5 / (int)(local_2b4 - 1)) + (short)param_4;
          iVar6 = iVar6 + 1;
          iVar9 = iVar9 + (param_5 - param_3);
          iVar5 = iVar5 + (param_6 - param_4);
        } while (iVar6 < (int)local_2b4);
      }
      psVar4 = local_20c + 1;
      local_2a8 = 0;
      local_2ac = 0;
      local_2a4 = 0;
      iVar5 = -4;
      puVar8 = (undefined2 *)((int)&local_210 + local_2b4 * 4 + 2);
      do {
        psVar4[-1] = local_29c[0];
        iVar6 = 1;
        *psVar4 = local_29c[1];
        psVar2 = psVar4;
        if (1 < (int)(local_2b4 - 1)) {
          do {
            sVar3 = FUN_004bd280(iVar5,local_2a8 + 4);
            psVar2[1] = sVar3 + local_29c[iVar6 * 2];
            sVar3 = FUN_004bd280(0xfffffffe,2);
            iVar9 = iVar6 * 2;
            iVar6 = iVar6 + 1;
            psVar2[2] = sVar3 + local_29c[iVar9 + 1];
            psVar2 = psVar2 + 2;
          } while (iVar6 < (int)(local_2b4 - 1));
        }
        uVar1 = *(undefined2 *)((int)&local_2a0 + local_2b4 * 4 + 2);
        puVar8[-1] = *(undefined2 *)(&local_2a0 + local_2b4);
        *puVar8 = uVar1;
        local_2a8 = local_2a8 + 1;
        local_2c[local_2a8] =
             (-local_2a4 - 0x24U & 0xff | (-1 - local_2ac) * 0x100) << 0x10 | 0xf0f0;
        iVar5 = iVar5 + -1;
        psVar4 = psVar4 + 0x30;
        local_2a4 = local_2a4 + 0x10;
        local_2ac = local_2ac + 0x14;
        puVar8 = puVar8 + 0x30;
      } while (-9 < iVar5);
      local_14 = DAT_0057f484 + 0x3c;
      local_10 = 0;
      local_2c[0] = local_2b4;
    }
    FUN_00414ba0(local_23c);
    local_4 = 0xffffffff;
    Engine_ACTIVATE_COMPANION_4bdf40();
  }
  ExceptionList = local_c;
  return;
}

