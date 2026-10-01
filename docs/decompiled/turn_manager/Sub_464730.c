
int __fastcall FUN_00464730(int param_1)

{
  int iVar1;
  int iVar2;
  int *piVar3;
  int iVar4;
  int iVar5;
  undefined4 *puVar6;
  int iVar7;
  int local_10;
  int local_c;
  int local_8;
  
  Engine_ADD_GOLD_447c60();
  iVar1 = FUN_00445db0();
  iVar4 = -1;
  iVar5 = 0;
  *(int *)(param_1 + 0x24) = iVar1;
  local_8 = -1;
  local_c = -1;
  local_10 = 0;
  if (0 < iVar1) {
    do {
      iVar1 = iVar5;
      Engine_ADD_GOLD_447c60(iVar5);
      Engine_ADD_GOLD_446200(iVar1);
      iVar2 = Engine_ADD_TEMP_SKILL_465f30(5);
      iVar1 = iVar5;
      Engine_ADD_GOLD_447c60(iVar5);
      piVar3 = (int *)Engine_ADD_GOLD_446200(iVar1);
      iVar1 = *(int *)(*piVar3 + 0x6c);
      iVar7 = iVar5;
      Engine_ADD_GOLD_447c60(iVar5);
      piVar3 = (int *)Engine_ADD_GOLD_446200(iVar7);
      if ((iVar4 < iVar2) ||
         ((iVar2 == iVar4 &&
          ((local_8 < iVar1 || ((iVar1 == local_8 && (local_c < *(int *)(*piVar3 + 0x94))))))))) {
        iVar4 = iVar2;
        local_10 = iVar5;
        local_c = *(int *)(*piVar3 + 0x94);
        local_8 = iVar1;
      }
      iVar5 = iVar5 + 1;
    } while (iVar5 < *(int *)(param_1 + 0x24));
  }
  iVar4 = Engine_GET_GAME_ID_4481d0();
  if (((*(int *)(iVar4 + 0x20) == 2) ||
      (iVar4 = Engine_GET_GAME_ID_4481d0(), *(int *)(iVar4 + 0x20) == 6)) ||
     (iVar4 = Engine_GET_GAME_ID_4481d0(), *(int *)(iVar4 + 0x20) == 5)) {
    local_10 = 0;
    *(undefined4 *)(param_1 + 0x24) = 1;
  }
  iVar4 = *(int *)(param_1 + 0x24);
  iVar1 = 0;
  if (0 < iVar4) {
    puVar6 = (undefined4 *)(param_1 + 0x14);
    do {
      iVar5 = iVar1 + local_10;
      iVar7 = *(int *)(param_1 + 0x24);
      iVar4 = iVar5 / iVar7;
      *puVar6 = 0;
      iVar1 = iVar1 + 1;
      puVar6[-4] = iVar5 % iVar7;
      puVar6 = puVar6 + 1;
    } while (iVar1 < *(int *)(param_1 + 0x24));
  }
  *(undefined4 *)(param_1 + 0x2c) = 1;
  *(undefined1 *)(param_1 + 0x30) = 0;
  *(undefined1 *)(param_1 + 0x31) = 0;
  *(undefined1 *)(param_1 + 0x32) = 0;
  *(undefined1 *)(param_1 + 0x40) = 0;
  return iVar4;
}

