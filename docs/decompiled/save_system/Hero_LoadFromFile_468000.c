
void __fastcall Hero_LoadFromFile_468000(int param_1)

{
  undefined4 uVar1;
  
  uVar1 = Engine_ADD_ANIMEFFECT_TO_GRID_4bddc0
                    (*(undefined4 *)(param_1 + 0xd8),*(undefined4 *)(param_1 + 0xdc),
                     L"jhgsd&*(d9shgsf098aLKJ",*(undefined4 *)(param_1 + 0xd0),
                     *(undefined4 *)(param_1 + 0xc0));
  uVar1 = Engine_ADD_ANIMEFFECT_TO_GRID_4bddc0(L"pqhero",uVar1);
  FUN_004d76e0(L"Saves",uVar1);
  return;
}

