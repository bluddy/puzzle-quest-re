
undefined1 __thiscall FUN_00474d20(int param_1,undefined4 param_2)

{
  char cVar1;
  undefined2 uVar2;
  int iVar3;
  undefined4 uVar4;
  ushort *puVar5;
  ushort *puVar6;
  ushort *puVar7;
  ushort *puVar8;
  undefined4 *puVar9;
  undefined4 uVar10;
  undefined1 *puVar11;
  undefined1 local_81;
  undefined1 local_64 [12];
  undefined1 local_58 [12];
  undefined1 local_4c [64];
  void *local_c;
  undefined1 *puStack_8;
  uint local_4;
  
  local_4 = 0xffffffff;
  puStack_8 = &LAB_00514d80;
  local_c = ExceptionList;
  ExceptionList = &local_c;
  FUN_004bf9b0();
  local_4 = 0;
  local_81 = 0;
  cVar1 = FUN_004bffe0(param_2);
  if ((cVar1 != '\0') && (cVar1 = FUN_004bfc90(), cVar1 != '\0')) {
    local_81 = 1;
    iVar3 = FUN_004bfa40(L"Spell");
    if (iVar3 != 0) {
      uVar10 = 0xffffffff;
      uVar4 = FUN_004bfb60(iVar3,&DAT_00521458);
      Engine_ACTIVATE_COMPANION_4be530(uVar4,uVar10);
      local_4 = CONCAT31(local_4._1_3_,1);
      puVar5 = (ushort *)Engine_ACTIVATE_COMPANION_4be7e0(3);
      puVar6 = (ushort *)Engine_ACTIVATE_COMPANION_4be7e0(2);
      puVar7 = (ushort *)Engine_ACTIVATE_COMPANION_4be7e0(1);
      puVar8 = (ushort *)Engine_ACTIVATE_COMPANION_4be7e0(0);
      *(uint *)(param_1 + 4) =
           (((uint)*puVar5 << 8 | (uint)*puVar6) << 8 | (uint)*puVar7) << 8 | (uint)*puVar8;
      puVar9 = (undefined4 *)FUN_004bfa60(iVar3);
      while (puVar9 != (undefined4 *)0x0) {
        iVar3 = wcscmp((wchar_t *)*puVar9,L"Text");
        if (iVar3 == 0) {
          uVar10 = 0xffffffff;
          uVar4 = FUN_004bfb60(puVar9,L"name");
          Engine_ACTIVATE_COMPANION_4be530(uVar4,uVar10);
          puVar11 = local_64;
          local_4._0_1_ = 2;
          Engine_GET_TEXT_4b4500(puVar11);
          Engine_GET_TEXT_4b4050(puVar11);
          uVar4 = Engine_ADD_ANIMEFFECT_TO_GRID_4bddc0();
          Engine_TUTORIAL_GAME_RUN_4be780(uVar4);
          local_4._0_1_ = 1;
          Engine_ACTIVATE_COMPANION_4bdf40();
          uVar10 = 0xffffffff;
          uVar4 = FUN_004bfb60(puVar9,&PTR_Rsrc_DATA___GDF_THUMBNAIL_407_130740__00521428);
          Engine_ACTIVATE_COMPANION_4be530(uVar4,uVar10);
          puVar11 = local_58;
          local_4._0_1_ = 3;
          Engine_GET_TEXT_4b4500(puVar11);
          Engine_GET_TEXT_4b4050(puVar11);
          uVar4 = Engine_ADD_ANIMEFFECT_TO_GRID_4bddc0();
          Engine_TUTORIAL_GAME_RUN_4be780(uVar4);
          local_4._0_1_ = 1;
          Engine_ACTIVATE_COMPANION_4bdf40();
          uVar10 = 0xffffffff;
          uVar4 = FUN_004bfb60(puVar9,&PTR_Rsrc_DATA___GDF_THUMBNAIL_407_130740__00522ae8);
          Engine_ACTIVATE_COMPANION_4be530(uVar4,uVar10);
          puVar11 = local_4c;
          local_4 = CONCAT31(local_4._1_3_,4);
          Engine_GET_TEXT_4b4500(puVar11);
          Engine_GET_TEXT_4b4050(puVar11);
          uVar4 = Engine_ADD_ANIMEFFECT_TO_GRID_4bddc0();
          Engine_TUTORIAL_GAME_RUN_4be780(uVar4);
LAB_004750a4:
          local_4 = CONCAT31(local_4._1_3_,1);
          Engine_ACTIVATE_COMPANION_4bdf40();
        }
        else {
          iVar3 = wcscmp((wchar_t *)*puVar9,L"Cost");
          if (iVar3 == 0) {
            uVar2 = FUN_004bfb90(puVar9,L"earth");
            *(undefined2 *)(param_1 + 0x2c) = uVar2;
            uVar2 = FUN_004bfb90(puVar9,L"fire");
            *(undefined2 *)(param_1 + 0x2e) = uVar2;
            uVar2 = FUN_004bfb90(puVar9,&DAT_00521e50);
            *(undefined2 *)(param_1 + 0x30) = uVar2;
            uVar2 = FUN_004bfb90(puVar9,L"water");
            *(undefined2 *)(param_1 + 0x32) = uVar2;
          }
          else {
            iVar3 = wcscmp((wchar_t *)*puVar9,L"Learn");
            if (iVar3 == 0) {
              uVar4 = FUN_004bfb90(puVar9,L"score");
              *(undefined4 *)(param_1 + 0x38) = uVar4;
              uVar4 = FUN_004bfb90(puVar9,L"masks");
              *(undefined4 *)(param_1 + 0x3c) = uVar4;
              uVar4 = FUN_004bfb90(puVar9,L"keys");
              *(undefined4 *)(param_1 + 0x40) = uVar4;
            }
            else {
              iVar3 = wcscmp((wchar_t *)*puVar9,L"Data");
              if (iVar3 == 0) {
                uVar4 = FUN_004bfb90(puVar9,L"cooldown");
                *(undefined4 *)(param_1 + 0x44) = uVar4;
              }
              else {
                iVar3 = wcscmp((wchar_t *)*puVar9,L"Input");
                if (iVar3 == 0) {
                  uVar10 = 0xffffffff;
                  *(undefined4 *)(param_1 + 0x34) = 0;
                  uVar4 = FUN_004bfb60(puVar9,L"type");
                  Engine_ACTIVATE_COMPANION_4be530(uVar4,uVar10);
                  local_4 = CONCAT31(local_4._1_3_,5);
                  cVar1 = FUN_004bddd0(&DAT_00521a3c);
                  if (cVar1 == '\0') {
                    cVar1 = FUN_004bddd0(L"column");
                    if (cVar1 == '\0') {
                      cVar1 = FUN_004bddd0(L"grid");
                      if (cVar1 != '\0') {
                        *(undefined4 *)(param_1 + 0x34) = 3;
                      }
                    }
                    else {
                      *(undefined4 *)(param_1 + 0x34) = 1;
                    }
                  }
                  else {
                    *(undefined4 *)(param_1 + 0x34) = 2;
                  }
                  goto LAB_004750a4;
                }
              }
            }
          }
        }
        puVar9 = (undefined4 *)FUN_004bfa80();
      }
      local_4 = local_4 & 0xffffff00;
      Engine_ACTIVATE_COMPANION_4bdf40();
    }
  }
  local_4 = 0xffffffff;
  FUN_004bff80();
  ExceptionList = local_c;
  return local_81;
}

