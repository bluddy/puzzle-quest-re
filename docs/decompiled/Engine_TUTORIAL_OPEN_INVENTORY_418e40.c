
/* WARNING: Globals starting with '_' overlap smaller symbols at the same address */

void Engine_TUTORIAL_OPEN_INVENTORY_418e40(undefined4 param_1,undefined4 param_2)

{
  int iVar1;
  
  FUN_00421e30(0x5dc);
  iVar1 = FUN_004cd860(param_2);
  if (iVar1 != -1) {
    FUN_004c6120(1 << ((byte)iVar1 & 0x1f));
  }
  if (DAT_00581264 == '\0') {
    FUN_004c5e50(L"Assets\\Screens\\HeroDetailsMenu.xml");
  }
  _DAT_005812b4 = param_1;
  _DAT_005812b8 = param_2;
  FUN_004c27d0(0xffffffff,0xffffffff);
  return;
}

