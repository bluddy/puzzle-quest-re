
undefined4 Save_CheckDamaged_44cbf0(void)

{
  char cVar1;
  undefined4 uVar2;
  undefined4 in_stack_00000014;
  undefined1 *puVar3;
  undefined1 local_24 [12];
  undefined1 local_18 [12];
  void *local_c;
  undefined1 *puStack_8;
  int local_4;
  
  local_4 = 0xffffffff;
  puStack_8 = &LAB_00512c68;
  local_c = ExceptionList;
  ExceptionList = &local_c;
  uVar2 = Engine_ADD_ANIMEFFECT_TO_GRID_4bddc0(L"pqhero",in_stack_00000014);
  cVar1 = FUN_004d8040(L"Saves",uVar2);
  if (cVar1 == '\0') {
    FUN_004bdb30();
    local_4 = 0;
    Engine_ACTIVATE_COMPANION_4be530(L"[KING_X]",0xffffffff);
    local_4._0_1_ = 1;
    uVar2 = Engine_ADD_ANIMEFFECT_TO_GRID_4bddc0();
    puVar3 = local_18;
    Engine_GET_TEXT_4b4500(puVar3,uVar2);
    Engine_GET_TEXT_4b4050(puVar3);
    uVar2 = Engine_ADD_ANIMEFFECT_TO_GRID_4bddc0();
    FUN_004bdff0(local_24,uVar2);
    local_4._0_1_ = 0;
    Engine_ACTIVATE_COMPANION_4bdf40();
    uVar2 = Engine_ADD_ANIMEFFECT_TO_GRID_4bddc0(L"pqhero",in_stack_00000014);
    cVar1 = FUN_004d8040(L"Saves",uVar2);
    if (cVar1 == '\0') {
      Engine_ACTIVATE_COMPANION_4be530(L"[KING_Xa]",0xffffffff);
      local_4._0_1_ = 2;
      uVar2 = Engine_ADD_ANIMEFFECT_TO_GRID_4bddc0();
      puVar3 = local_18;
      Engine_GET_TEXT_4b4500(puVar3,uVar2);
      Engine_GET_TEXT_4b4050(puVar3);
      uVar2 = Engine_ADD_ANIMEFFECT_TO_GRID_4bddc0();
      FUN_004bdff0(local_24,uVar2);
      local_4 = (uint)local_4._1_3_ << 8;
      Engine_ACTIVATE_COMPANION_4bdf40();
      uVar2 = Engine_ADD_ANIMEFFECT_TO_GRID_4bddc0(L"pqhero",in_stack_00000014);
      cVar1 = FUN_004d8040(L"Saves",uVar2);
      local_4 = 0xffffffff;
      if (cVar1 == '\0') {
        Engine_ACTIVATE_COMPANION_4bdf40();
        ExceptionList = local_c;
        return 1;
      }
    }
    local_4 = 0xffffffff;
    Engine_ACTIVATE_COMPANION_4bdf40();
  }
  ExceptionList = local_c;
  return 0;
}

