with Support, Eval ; use Support, Eval;

procedure Test_Eval_AB is
begin
   Assert (E_And (True, True) = True);
   Assert (E_And (True, False) = False);
   Assert (E_And (False, True) = False);
end;

--# eval.adb
--  /eval/  l+ ## 0
--  /retTrue/  l+ ## 0
--  /retFalse/ l+ ## 0
--  /retVal/   l+ ## 0
