
void Engine_PLAY_SOUND_4b38a0(int param_1)

{
  int iVar1;
  int *piVar2;
  undefined1 local_4 [4];
  
  iVar1 = DAT_0059a428;
  if (param_1 != 0) {
    piVar2 = (int *)FUN_004b28c0(local_4,&param_1);
    if ((*piVar2 != *(int *)(iVar1 + 8)) &&
       (piVar2 = *(int **)(*piVar2 + 0x10), piVar2 != (int *)0x0)) {
      (**(code **)(*piVar2 + 0x28))();
    }
  }
  return;
}

