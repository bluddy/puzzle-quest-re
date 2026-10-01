// refs 0x0043f870 @ 0047e756

/* WARNING: Removing unreachable block (ram,0x0047e609) */
/* WARNING: Removing unreachable block (ram,0x0047e5c8) */
/* WARNING: Removing unreachable block (ram,0x0047e7fe) */

void __fastcall FUN_0047e500(int param_1)

{
  bool bVar1;
  char cVar2;
  undefined4 uVar3;
  int iVar4;
  int iVar5;
  int iVar6;
  undefined4 *puVar7;
  undefined1 *puVar8;
  undefined4 *puVar9;
  undefined4 local_13c;
  undefined4 local_138;
  undefined1 local_134 [296];
  void *local_c;
  undefined1 *puStack_8;
  undefined4 local_4;
  
  puStack_8 = &LAB_0051530b;
  local_c = ExceptionList;
  bVar1 = false;
  local_4 = 0;
  iVar6 = 1;
  ExceptionList = &local_c;
  do {
    iVar4 = 0;
    do {
      FUN_0043fc10();
      cVar2 = CBoard_CheckMatch_47c8c0(iVar4,iVar6,1,local_134);
      if (cVar2 != '\0') {
        FUN_0047e470(local_134);
        bVar1 = true;
      }
      cVar2 = CBoard_CheckMatch_47c8c0(iVar4,iVar6,0,local_134);
      if (cVar2 != '\0') {
        FUN_0047e470(local_134);
        bVar1 = true;
      }
      iVar5 = 0;
      iVar4 = iVar4 + 1;
    } while (iVar4 < 8);
    iVar6 = iVar6 + 1;
  } while (iVar6 < 9);
  puVar7 = (undefined4 *)(param_1 + 0x3e4);
  for (iVar6 = 0x12; iVar6 != 0; iVar6 = iVar6 + -1) {
    *puVar7 = 0;
    puVar7 = puVar7 + 1;
  }
  iVar6 = iVar5;
  for (iVar4 = 0; iVar4 < 0; iVar4 = iVar4 + 1) {
    if (0 < *(int *)(iVar6 + 0xc)) {
      FUN_0047a6c0(iVar6);
    }
    iVar6 = iVar6 + 0x128;
  }
  for (iVar6 = 0; iVar6 < 0; iVar6 = iVar6 + 1) {
    if (0 < *(int *)(iVar5 + 0xc)) {
      FUN_0047cd90(iVar5);
    }
    iVar5 = iVar5 + 0x128;
  }
  if (bVar1) {
    *(undefined4 *)(param_1 + 0x34c) = 2;
    FUN_0047ae80();
  }
  else {
    *(undefined4 *)(param_1 + 0x3c8) = 0;
    iVar6 = Engine_GET_GAME_ID_4481d0();
    if (*(int *)(iVar6 + 0x20) == 4) {
      if (*(char *)(param_1 + 0x368) == '\0') {
        iVar6 = *(int *)(param_1 + 0x358) + -1;
        *(int *)(param_1 + 0x358) = iVar6;
        if (iVar6 < 1) {
          *(undefined4 *)(param_1 + 0x34c) = 8;
          uVar3 = Engine_ADD_ANIMEFFECT_TO_GRID_4bddc0();
          if (DAT_0059a4d4 != (code *)0x0) {
            (*DAT_0059a4d4)(uVar3,0,0,0,0);
          }
        }
      }
      else {
        *(undefined1 *)(param_1 + 0x368) = 0;
        *(undefined4 *)(param_1 + 0x34c) = 3;
      }
    }
    else {
      cVar2 = FUN_0047c830();
      if (cVar2 == '\0') {
        Engine_EXTRA_TURN_4646e0();
        FUN_00464e30();
        cVar2 = FUN_0047c830();
        if (cVar2 == '\0') {
          Engine_EXTRA_TURN_4646e0();
          cVar2 = FUN_00464b70();
          if (cVar2 == '\0') {
            *(undefined4 *)(param_1 + 0x34c) = 5;
            *(undefined4 *)(param_1 + 0x354) = 0;
            FUN_0040f560();
            if (*(char *)(param_1 + 0x394) == '\0') {
              *(undefined4 *)(param_1 + 0x34c) = 1;
            }
          }
          else {
            Engine_EXTRA_TURN_4646e0();
            FUN_00464bf0();
            Engine_EXTRA_TURN_4646e0();
            cVar2 = FUN_00464f30();
            if (cVar2 == '\0') {
              *(undefined4 *)(param_1 + 0x34c) = 4;
            }
            else {
              *(undefined4 *)(param_1 + 0x34c) = 3;
            }
            FUN_0043fc10();
            puVar7 = &local_138;
            puVar9 = &local_13c;
            puVar8 = local_134;
            CBattleManager_GetSingleton(puVar8,puVar9,puVar7);
            cVar2 = FUN_004406f0(puVar8,puVar9,puVar7);
            if (cVar2 == '\0') {
              FUN_0040f560();
            }
            else {
              FUN_0040f610(local_13c,local_138,DAT_0057f484 + 10000);
            }
            if (*(int *)(param_1 + 0x34c) == 4) {
              FUN_0040f560();
            }
            if (DAT_0059a530 == 1) {
              Engine_EXTRA_TURN_4646e0();
              cVar2 = FUN_00464f30();
              if (cVar2 != '\0') {
                FUN_0040f690();
              }
            }
          }
        }
      }
    }
  }
  ExceptionList = local_c;
  return;
}

