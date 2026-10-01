
void __thiscall
Engine_TUTORIAL_GAME_ADD_HERO_4487e0
          (int param_1,undefined4 param_2,undefined4 param_3,undefined4 param_4,ushort *param_5,
          undefined4 param_6,undefined4 param_7,undefined4 param_8,undefined4 param_9,
          undefined4 param_10,undefined4 param_11,undefined4 param_12,ushort *param_13,
          ushort *param_14,ushort *param_15,ushort *param_16)

{
  undefined4 uVar1;
  uint uVar2;
  undefined1 *puVar3;
  undefined1 local_24 [12];
  undefined1 local_18 [12];
  void *local_c;
  undefined1 *puStack_8;
  undefined4 local_4;
  
  local_4 = 0xffffffff;
  puStack_8 = &LAB_00512978;
  local_c = ExceptionList;
  ExceptionList = &local_c;
  Engine_ACTIVATE_COMPANION_4be530(param_2,0xffffffff);
  puVar3 = local_24;
  local_4 = 0;
  Engine_GET_TEXT_4b4500(puVar3);
  Engine_GET_TEXT_4b4050(puVar3);
  uVar1 = Engine_ADD_ANIMEFFECT_TO_GRID_4bddc0();
  Engine_TUTORIAL_GAME_RUN_4be780(uVar1);
  local_4 = 0xffffffff;
  Engine_ACTIVATE_COMPANION_4bdf40();
  Engine_TUTORIAL_GAME_RUN_4be780(L"Assets\\Portraits");
  Engine_ACTIVATE_COMPANION_4be530(&DAT_0052146c,0xffffffff);
  local_4 = 1;
  FUN_004be790(local_24);
  local_4 = 0xffffffff;
  Engine_ACTIVATE_COMPANION_4bdf40();
  Engine_ACTIVATE_COMPANION_4be530(param_3,0xffffffff);
  local_4 = 2;
  FUN_004be790(local_18);
  local_4 = 0xffffffff;
  Engine_ACTIVATE_COMPANION_4bdf40();
  *(undefined4 *)(param_1 + 0x70) = param_4;
  uVar2 = (((uint)param_5[3] << 8 | (uint)param_5[2]) << 8 | (uint)param_5[1]) << 8 | (uint)*param_5
  ;
  FUN_00459730(uVar2);
  uVar1 = FUN_00458870(uVar2);
  *(undefined4 *)(param_1 + 0x6c) = uVar1;
  *(undefined4 *)(param_1 + 0x50) = param_6;
  *(undefined4 *)(param_1 + 0x54) = param_7;
  *(undefined4 *)(param_1 + 0x58) = param_8;
  *(undefined4 *)(param_1 + 0x5c) = param_9;
  *(undefined4 *)(param_1 + 100) = param_11;
  *(undefined4 *)(param_1 + 0x60) = param_10;
  uVar2 = 0;
  *(undefined4 *)(param_1 + 0x68) = param_12;
  if ((param_13 != (ushort *)0x0) && (*param_13 != 0)) {
    uVar2 = (((uint)param_13[3] << 8 | (uint)param_13[2]) << 8 | (uint)param_13[1]) << 8 |
            (uint)*param_13;
  }
  Engine_GET_CURRENT_RUNE_CODE_44f8e0(uVar2);
  uVar1 = Engine_SET_ITEM_41f6e0(uVar2);
  *(undefined4 *)(param_1 + 0x74) = uVar1;
  uVar2 = 0;
  if ((param_14 != (ushort *)0x0) && (*param_14 != 0)) {
    uVar2 = (((uint)param_14[3] << 8 | (uint)param_14[2]) << 8 | (uint)param_14[1]) << 8 |
            (uint)*param_14;
  }
  Engine_GET_CURRENT_RUNE_CODE_44f8e0(uVar2);
  uVar1 = Engine_SET_ITEM_41f6e0(uVar2);
  *(undefined4 *)(param_1 + 0x78) = uVar1;
  uVar2 = 0;
  if ((param_15 != (ushort *)0x0) && (*param_15 != 0)) {
    uVar2 = (((uint)param_15[3] << 8 | (uint)param_15[2]) << 8 | (uint)param_15[1]) << 8 |
            (uint)*param_15;
  }
  Engine_GET_CURRENT_RUNE_CODE_44f8e0(uVar2);
  uVar1 = Engine_SET_ITEM_41f6e0(uVar2);
  *(undefined4 *)(param_1 + 0x7c) = uVar1;
  uVar2 = 0xffffffff;
  if ((param_16 != (ushort *)0x0) && (*param_16 != 0)) {
    uVar2 = (((uint)param_16[3] << 8 | (uint)param_16[2]) << 8 | (uint)param_16[1]) << 8 |
            (uint)*param_16;
  }
  Engine_GET_CURRENT_RUNE_CODE_44f8e0(uVar2);
  uVar1 = Engine_SET_ITEM_41f6e0(uVar2);
  *(undefined4 *)(param_1 + 0x80) = uVar1;
  ExceptionList = local_c;
  return;
}

