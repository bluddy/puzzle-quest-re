
void Lua_GET_STATUS_EFFECT_ON_PLAYER(undefined4 param_1)

{
  int iVar1;
  undefined4 uVar2;
  int iVar3;
  char *pcVar4;
  byte bStack_46;
  byte bStack_45;
  basic_string<char,struct_std::char_traits<char>,class_std::allocator<char>_> local_38 [28];
  ushort local_1c;
  ushort local_1a;
  ushort local_18;
  ushort local_16;
  undefined2 local_14;
  undefined4 local_10;
  void *local_c;
  undefined1 *puStack_8;
  undefined4 local_4;
  
  local_4 = 0xffffffff;
  puStack_8 = &LAB_00515e18;
  local_c = ExceptionList;
  local_10 = DAT_0057faa0;
  ExceptionList = &local_c;
  iVar1 = FUN_004f6ca0(param_1,1);
  if (iVar1 == 0) {
    pcVar4 = "GET_STATUS_EFFECT_ON_PLAYER: arg 1 is not an integer";
    Engine_ACTIVATE_COMPANION_483650("GET_STATUS_EFFECT_ON_PLAYER: arg 1 is not an integer");
    Engine_ACTIVATE_COMPANION_4836e0(pcVar4);
  }
  else {
    FUN_004f6db0(param_1,1);
    uVar2 = FUN_0050432c();
    iVar1 = FUN_004f6ca0(param_1,2);
    if (iVar1 == 0) {
      pcVar4 = "GET_STATUS_EFFECT_ON_PLAYER: arg 2 is not an integer";
      Engine_ACTIVATE_COMPANION_483650("GET_STATUS_EFFECT_ON_PLAYER: arg 2 is not an integer");
      Engine_ACTIVATE_COMPANION_4836e0(pcVar4);
    }
    else {
      FUN_004f6db0(param_1,2);
      iVar1 = FUN_0050432c();
      Engine_ADD_GOLD_447c60(uVar2);
      iVar3 = Engine_ADD_GOLD_446200(uVar2);
      iVar1 = *(int *)(*(int *)(iVar3 + 0x5c) + iVar1 * 8);
      iVar3 = FUN_00464430();
      uVar2 = *(undefined4 *)(iVar1 * 0x44 + *(int *)(iVar3 + 8) + 4);
      local_1c = (ushort)uVar2 & 0xff;
      bStack_46 = (byte)((uint)uVar2 >> 0x10);
      bStack_45 = (byte)((uint)uVar2 >> 0x18);
      local_1a = (ushort)(byte)((uint)uVar2 >> 8);
      local_16 = (ushort)bStack_45;
      local_18 = (ushort)bStack_46;
      local_14 = 0;
      Engine_ACTIVATE_COMPANION_4be530(&local_1c,0xffffffff);
      local_4 = 0;
      iVar1 = Engine_GET_CHARACTER_ID_4bec10(local_38);
      if (*(uint *)(iVar1 + 0x18) < 0x10) {
        iVar1 = iVar1 + 4;
      }
      else {
        iVar1 = *(int *)(iVar1 + 4);
      }
      FUN_004f7090(param_1,iVar1);
      std::basic_string<char,struct_std::char_traits<char>,class_std::allocator<char>_>::
      ~basic_string<char,struct_std::char_traits<char>,class_std::allocator<char>_>(local_38);
      local_4 = 0xffffffff;
      Engine_ACTIVATE_COMPANION_4bdf40();
    }
  }
  ExceptionList = local_c;
  FUN_005042e3();
  return;
}

