
void __thiscall Hero_ReadHeader_468450(int param_1,undefined4 param_2)

{
  char cVar1;
  undefined4 uVar2;
  undefined1 local_24 [12];
  undefined1 local_18 [12];
  void *local_c;
  undefined1 *puStack_8;
  uint local_4;
  
  local_4 = 0xffffffff;
  puStack_8 = &LAB_00514530;
  local_c = ExceptionList;
  ExceptionList = &local_c;
  FUN_004bdb30();
  local_4 = 0;
  FUN_00467e00(local_18);
  Engine_TUTORIAL_GAME_RUN_4be780(param_2);
  *(undefined1 *)(param_1 + 0xbc) = 1;
  FUN_004bdb30();
  local_4 = CONCAT31(local_4._1_3_,1);
  FUN_00467e00(local_24);
  if ((*(char *)(param_1 + 0x22c) != '\0') && (*(char *)(param_1 + 0x22d) == '\0')) {
    cVar1 = FUN_004be1a0(local_24);
    if (cVar1 != '\0') {
      uVar2 = Engine_ADD_ANIMEFFECT_TO_GRID_4bddc0(L"pqhero",*(undefined4 *)(param_1 + 0xd0));
      uVar2 = Engine_ADD_ANIMEFFECT_TO_GRID_4bddc0(uVar2);
      FUN_004d7850(L"Saves",uVar2);
    }
  }
  *(undefined1 *)(param_1 + 0xbc) = 1;
  local_4 = local_4 & 0xffffff00;
  Engine_ACTIVATE_COMPANION_4bdf40();
  local_4 = 0xffffffff;
  Engine_ACTIVATE_COMPANION_4bdf40();
  ExceptionList = local_c;
  return;
}

