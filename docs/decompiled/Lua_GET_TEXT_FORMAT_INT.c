
void Lua_GET_TEXT_FORMAT_INT(undefined4 param_1)

{
  int iVar1;
  undefined4 uVar2;
  wchar_t *_Format;
  size_t _Count;
  undefined1 *puVar3;
  char *pcVar4;
  undefined1 local_844 [24];
  basic_string<char,struct_std::char_traits<char>,class_std::allocator<char>_> abStack_82c [28];
  wchar_t local_810 [1024];
  undefined4 local_10;
  void *local_c;
  undefined1 *puStack_8;
  int local_4;
  
  local_4 = 0xffffffff;
  puStack_8 = &LAB_00515b66;
  local_c = ExceptionList;
  local_10 = DAT_0057faa0;
  ExceptionList = &local_c;
  Engine_ACTIVATE_COMPANION_4be530(&DAT_0051b07c,0xffffffff);
  local_4 = 0;
  iVar1 = FUN_004f6d00(param_1,1);
  if (iVar1 == 0) {
    pcVar4 = "GET_TEXT_FORMAT_INT: arg 1 is not a string";
    Engine_ACTIVATE_COMPANION_483650("GET_TEXT_FORMAT_INT: arg 1 is not a string");
    Engine_ACTIVATE_COMPANION_4836e0(pcVar4);
    local_4 = 0xffffffff;
    Engine_ACTIVATE_COMPANION_4bdf40();
  }
  else {
    uVar2 = FUN_004f6e50(param_1,1);
    Engine_ACTIVATE_COMPANION_4bf1a0(uVar2);
    iVar1 = FUN_004f6ca0(param_1,2);
    if (iVar1 == 0) {
      pcVar4 = "GET_TEXT_FORMAT_INT: arg 2 is not an integer";
      Engine_ACTIVATE_COMPANION_483650("GET_TEXT_FORMAT_INT: arg 2 is not an integer");
      Engine_ACTIVATE_COMPANION_4836e0(pcVar4);
      local_4 = 0xffffffff;
      Engine_ACTIVATE_COMPANION_4bdf40();
    }
    else {
      FUN_004f6db0(param_1,2);
      _Format = (wchar_t *)FUN_0050432c();
      puVar3 = local_844;
      Engine_GET_TEXT_4b4500(puVar3);
      Engine_GET_TEXT_4b4050(puVar3);
      _Count = Engine_ADD_ANIMEFFECT_TO_GRID_4bddc0();
      swprintf(local_810,_Count,_Format);
      Engine_ACTIVATE_COMPANION_4be530(local_810,0xffffffff);
      local_4._0_1_ = 1;
      iVar1 = Engine_GET_CHARACTER_ID_4bec10(abStack_82c);
      if (*(uint *)(iVar1 + 0x18) < 0x10) {
        iVar1 = iVar1 + 4;
      }
      else {
        iVar1 = *(int *)(iVar1 + 4);
      }
      FUN_004f7090(param_1,iVar1);
      std::basic_string<char,struct_std::char_traits<char>,class_std::allocator<char>_>::
      ~basic_string<char,struct_std::char_traits<char>,class_std::allocator<char>_>(abStack_82c);
      local_4 = (uint)local_4._1_3_ << 8;
      Engine_ACTIVATE_COMPANION_4bdf40();
      local_4 = 0xffffffff;
      Engine_ACTIVATE_COMPANION_4bdf40();
    }
  }
  ExceptionList = local_c;
  FUN_005042e3();
  return;
}

