
void __fastcall Engine_ACTIVATE_COMPANION_4bdf40(undefined4 *param_1)

{
  LPCVOID pMem;
  HGLOBAL pvVar1;
  
  if ((param_1[1] != 0) && (pMem = (LPCVOID)*param_1, pMem != (LPCVOID)0x0)) {
    pvVar1 = GlobalHandle(pMem);
    GlobalUnlock(pvVar1);
    pvVar1 = GlobalHandle(pMem);
    GlobalFree(pvVar1);
    *param_1 = 0;
    param_1[1] = 0;
    param_1[2] = 0;
  }
  return;
}

