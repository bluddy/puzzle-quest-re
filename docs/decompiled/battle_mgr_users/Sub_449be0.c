// refs 0x0043f870 @ 00449e38

void __thiscall FUN_00449be0(int param_1,undefined4 param_2,undefined4 param_3)

{
  int iVar1;
  undefined4 uVar2;
  int iVar3;
  int iVar4;
  undefined4 uVar5;
  int *piVar6;
  undefined4 uVar7;
  int local_b4 [4];
  undefined1 local_a4;
  undefined1 local_a3;
  undefined1 local_a2;
  undefined1 local_a1;
  undefined4 local_9c;
  void *local_88;
  undefined4 local_84;
  undefined4 local_80;
  void *local_78;
  undefined4 local_74;
  undefined4 local_70;
  void *local_68;
  undefined4 local_64;
  undefined4 local_60;
  void *local_58;
  undefined4 local_54;
  undefined4 local_50;
  int local_4c [16];
  void *pvStack_c;
  undefined1 *puStack_8;
  undefined4 local_4;
  
  local_4 = 0xffffffff;
  puStack_8 = &LAB_00512af6;
  pvStack_c = ExceptionList;
  DAT_005828fc = DAT_005828fc + 1;
  ExceptionList = &pvStack_c;
  iVar1 = FUN_004bd310();
  *(int *)(param_1 + 0x24) = iVar1 % 1000 + DAT_005828fc;
  FUN_00408000();
  Engine_ADD_ANIMEFFECT_TO_GRID_483380();
  FUN_00483100();
  FUN_00447e00();
  *(undefined4 *)(param_1 + 0x20) = 5;
  iVar1 = Engine_EXTRA_TURN_4646e0();
  uVar5 = 0;
  *(undefined1 *)(iVar1 + 0x31) = 0;
  DAT_005af278 = 1;
  uVar2 = Engine_TUTORIAL_GET_HERO_475a90(0,0);
  Engine_QUEST_ABANDON_44e920(uVar2);
  iVar1 = Engine_QUEST_ABANDON_44d8e0(uVar2,uVar5);
  local_88 = (void *)0x0;
  local_84 = 0;
  local_80 = 0;
  local_78 = (void *)0x0;
  local_74 = 0;
  local_70 = 0;
  local_68 = (void *)0x0;
  local_64 = 0;
  local_60 = 0;
  local_58 = (void *)0x0;
  local_54 = 0;
  local_50 = 0;
  local_b4[1] = 0;
  local_b4[2] = 0;
  local_b4[3] = 0;
  local_a4 = 1;
  local_a3 = 1;
  local_a2 = 1;
  local_a1 = 0;
  local_9c = 0;
  *(undefined4 *)(iVar1 + 0x44) = 0;
  local_4c[0xf] = 0;
  local_4c[0] = 0;
  local_4c[1] = 0;
  local_4c[2] = 0;
  local_4c[3] = 0;
  local_4c[4] = 0;
  local_4c[5] = 0;
  local_4c[6] = 0;
  local_4 = 3;
  local_b4[0] = iVar1;
  if ((-1 < *(int *)(iVar1 + 0x1b4)) &&
     (iVar4 = *(int *)(*(int *)(iVar1 + 0x148) + *(int *)(iVar1 + 0x1b4) * 6), iVar4 != 0)) {
    iVar3 = FUN_004561a0();
    iVar4 = FUN_004560d0(iVar4);
    iVar4 = iVar4 * 0x270 + *(int *)(iVar3 + 8);
    if (*(int *)(iVar1 + 0x1b4) < 0) {
      iVar1 = 0;
    }
    else {
      iVar1 = (int)*(short *)(*(int *)(iVar1 + 0x148) + 4 + *(int *)(iVar1 + 0x1b4) * 6);
    }
    local_4c[*(int *)(iVar4 + 300)] =
         local_4c[*(int *)(iVar4 + 300)] +
         (iVar1 / *(int *)(iVar4 + 0x134)) * *(int *)(iVar4 + 0x130) + *(int *)(iVar4 + 0x128);
  }
  local_4c[7] = 0;
  local_4c[0xb] = 0;
  local_4c[8] = 0;
  local_4c[0xc] = 0;
  local_4c[9] = 0;
  local_4c[0xd] = 0;
  local_4c[10] = 0;
  local_4c[0xe] = 0;
  Engine_ADD_GOLD_447c60();
  FUN_00447cd0();
  piVar6 = local_b4;
  Engine_ADD_GOLD_447c60(piVar6);
  FUN_00447cf0(piVar6);
  iVar1 = Engine_ADD_ANIMEFFECT_TO_GRID_47a820();
  *(undefined1 *)(iVar1 + 0x393) = 1;
  iVar1 = Engine_ADD_ANIMEFFECT_TO_GRID_47a820();
  *(undefined1 *)(iVar1 + 0x394) = 0;
  iVar1 = Engine_ADD_ANIMEFFECT_TO_GRID_47a820();
  *(undefined1 *)(iVar1 + 0x392) = 0;
  iVar1 = Engine_ADD_ANIMEFFECT_TO_GRID_47a820();
  *(undefined1 *)(iVar1 + 0x391) = 0;
  iVar1 = Engine_ADD_ANIMEFFECT_TO_GRID_47a820();
  *(undefined1 *)(iVar1 + 0x390) = 0;
  iVar1 = Engine_ADD_ANIMEFFECT_TO_GRID_47a820();
  *(undefined1 *)(iVar1 + 0x395) = 1;
  iVar1 = Engine_ADD_ANIMEFFECT_TO_GRID_47a820();
  *(undefined1 *)(iVar1 + 0x396) = 1;
  iVar1 = Engine_EXTRA_TURN_4646e0();
  *(undefined4 *)(iVar1 + 0x34) = 0;
  iVar1 = Engine_ADD_ANIMEFFECT_TO_GRID_47a820();
  *(undefined1 *)(iVar1 + 0x397) = 0;
  CBattleManager_GetSingleton();
  FUN_004411e0();
  Engine_ADD_ANIMEFFECT_TO_GRID_47a820();
  Engine_TUTORIAL_GAME_PLAY_47bd80();
  uVar2 = Engine_GET_RANDOM_4bd280(0,2);
  uVar5 = Engine_GET_RANDOM_4bd280(0,7);
  uVar7 = 0x11;
  Engine_ADD_ANIMEFFECT_TO_GRID_47a820(uVar2,uVar5,0x11);
  FUN_0047aa50(uVar2,uVar5,uVar7);
  uVar2 = Engine_GET_RANDOM_4bd280(5,7);
  uVar5 = Engine_GET_RANDOM_4bd280(0,7);
  uVar7 = 0x11;
  Engine_ADD_ANIMEFFECT_TO_GRID_47a820(uVar2,uVar5,0x11);
  FUN_0047aa50(uVar2,uVar5,uVar7);
  uVar2 = Engine_GET_RANDOM_4bd280(3,4);
  uVar5 = Engine_GET_RANDOM_4bd280(0,7);
  uVar7 = 0x11;
  Engine_ADD_ANIMEFFECT_TO_GRID_47a820(uVar2,uVar5,0x11);
  FUN_0047aa50(uVar2,uVar5,uVar7);
  Engine_EXTRA_TURN_4646e0();
  FUN_00464730();
  iVar1 = Engine_ADD_ANIMEFFECT_TO_GRID_47a820();
  *(undefined1 *)(iVar1 + 0x391) = 0;
  FUN_0043b640();
  Engine_EXTRA_TURN_4646e0();
  FUN_00464850();
  FUN_0041e550(param_2,param_3);
  if (local_58 != (void *)0x0) {
                    /* WARNING: Subroutine does not return */
    operator_delete(local_58);
  }
  local_58 = (void *)0x0;
  local_54 = 0;
  local_50 = 0;
  if (local_68 != (void *)0x0) {
                    /* WARNING: Subroutine does not return */
    operator_delete(local_68);
  }
  local_68 = (void *)0x0;
  local_64 = 0;
  local_60 = 0;
  if (local_78 == (void *)0x0) {
    local_78 = (void *)0x0;
    local_74 = 0;
    local_70 = 0;
    if (local_88 == (void *)0x0) {
      ExceptionList = pvStack_c;
      return;
    }
                    /* WARNING: Subroutine does not return */
    operator_delete(local_88);
  }
                    /* WARNING: Subroutine does not return */
  operator_delete(local_78);
}

