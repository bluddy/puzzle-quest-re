
void __fastcall thunk_FUN_00474ba0(int param_1)

{
  wchar_t *pwVar1;
  byte bStack_21a;
  ushort uStack_218;
  ushort uStack_216;
  ushort uStack_214;
  ushort uStack_212;
  undefined2 uStack_210;
  wchar_t awStack_20c [260];
  undefined4 uStack_4;
  
  uStack_4 = DAT_0057faa0;
  uStack_210 = 0;
  uStack_218 = (ushort)*(byte *)(param_1 + 4);
  bStack_21a = (byte)((uint)*(undefined4 *)(param_1 + 4) >> 0x10);
  uStack_216 = (ushort)(byte)((uint)*(undefined4 *)(param_1 + 4) >> 8);
  uStack_214 = (ushort)bStack_21a;
  uStack_212 = (ushort)*(byte *)(param_1 + 7);
  swprintf(awStack_20c,0x52239c,L"Assets\\Spells",&uStack_218);
  pwVar1 = awStack_20c;
  Engine_ACTIVATE_COMPANION_483650(pwVar1);
  FUN_00483720(pwVar1);
  FUN_005042e3();
  return;
}

