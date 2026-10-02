
undefined4 Lua_GET_TEXT(undefined4 param_1)

{
  int iVar1;
  undefined4 uVar2;
  undefined1 *puVar3;
  char *pcVar4;
  undefined4 uVar5;
  undefined1 local_40 [24];
  basic_string<char,struct_std::char_traits<char>,class_std::allocator<char>_> local_28 [28];
  void *local_c;
  undefined1 *puStack_8;
  int local_4;
  
  local_4 = 0xffffffff;
  puStack_8 = &LAB_00515b40;
  local_c = ExceptionList;
  ExceptionList = &local_c;
  Engine_ACTIVATE_COMPANION_4be530(&DAT_0051b07c,0xffffffff);
  local_4 = 0;
  iVar1 = FUN_004f6d00(param_1,1);
  if (iVar1 == 0) {
    pcVar4 = "GET_TEXT: arg 1 is not a string";
    Engine_ACTIVATE_COMPANION_483650("GET_TEXT: arg 1 is not a string");
    Engine_ACTIVATE_COMPANION_4836e0(pcVar4);
    local_4 = 0xffffffff;
    Engine_ACTIVATE_COMPANION_4bdf40();
    ExceptionList = local_c;
    return 0;
  }
  uVar2 = FUN_004f6e50(param_1,1);
  Engine_ACTIVATE_COMPANION_4bf1a0(uVar2);
  puVar3 = local_40;
  uVar5 = 0xffffffff;
  Engine_GET_TEXT_4b4500(puVar3,0xffffffff);
  Engine_GET_TEXT_4b4050(puVar3);
  uVar2 = Engine_ADD_ANIMEFFECT_TO_GRID_4bddc0();
  Engine_ACTIVATE_COMPANION_4be530(uVar2,uVar5);
  local_4._0_1_ = 1;
  iVar1 = Engine_GET_CHARACTER_ID_4bec10(local_28);
  if (*(uint *)(iVar1 + 0x18) < 0x10) {
    iVar1 = iVar1 + 4;
  }
  else {
    iVar1 = *(int *)(iVar1 + 4);
  }
  FUN_004f7090(param_1,iVar1);
  std::basic_string<char,struct_std::char_traits<char>,class_std::allocator<char>_>::
  ~basic_string<char,struct_std::char_traits<char>,class_std::allocator<char>_>(local_28);
  local_4 = (uint)local_4._1_3_ << 8;
  Engine_ACTIVATE_COMPANION_4bdf40();
  local_4 = 0xffffffff;
  Engine_ACTIVATE_COMPANION_4bdf40();
  ExceptionList = local_c;
  return 1;
}

