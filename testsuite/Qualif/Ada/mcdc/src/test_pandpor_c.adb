with Support, PandPor; use Support, PandPor;

procedure Test_PandPor_C is
begin
   Assert (F (False, False, False) = False);
   Assert (F (False, False, True) = True);
end;

--# pandpor.adb
-- /eval(Stmt|Other)/      l! m!:"A",m!:"B"
-- /decisionTrue/  l+ 0
-- /decisionFalse/ l+ 0
-- /returnValue/   l+ 0

